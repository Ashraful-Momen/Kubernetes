#!/bin/bash
set -e

# Configuration
AWS_PROFILE="sarowar-ostad"
REGION="ap-south-1"
IMAGE_ID="ami-02d26659fd82cf299"
INSTANCE_TYPE="t3.medium"
DISK_SIZE=20
DISK_TYPE="gp3"
KEY_NAME="sarowar_ostad"
MY_IP=$(curl -s https://checkip.amazonaws.com)/32

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# AWS CLI common options
AWS_OPTS="--region $REGION --profile $AWS_PROFILE --output text"

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }


# Get default VPC and subnet
get_default_vpc() {
    log_info "Getting default VPC using profile: $AWS_PROFILE..."
    DEFAULT_VPC=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' $AWS_OPTS)
    if [ "$DEFAULT_VPC" == "None" ]; then
        log_error "No default VPC found in region $REGION"
    fi
    log_info "Default VPC: $DEFAULT_VPC"
}

get_default_subnet() {
    log_info "Getting default subnet..."
    DEFAULT_SUBNET=$(aws ec2 describe-subnets \
        --filters Name=vpc-id,Values=$DEFAULT_VPC Name=default-for-az,Values=true \
        --query 'Subnets[0].SubnetId' \
        $AWS_OPTS)
    if [ "$DEFAULT_SUBNET" == "None" ]; then
        log_error "No default subnet found in VPC $DEFAULT_VPC"
    fi
    
    SUBNET_CIDR=$(aws ec2 describe-subnets \
        --subnet-ids $DEFAULT_SUBNET \
        --query 'Subnets[0].CidrBlock' \
        $AWS_OPTS)
    log_info "Default Subnet: $DEFAULT_SUBNET (CIDR: $SUBNET_CIDR)"
}

# Find available private IPs
find_available_ips() {
    log_info "Finding available private IPs..."
    
    NETWORK_PREFIX=$(echo $SUBNET_CIDR | cut -d'.' -f1-3)
    START_IP=30
    IPS=()
    
    for i in {0..2}; do
        TARGET_IP="$NETWORK_PREFIX.$((START_IP + i))"
        
        IP_IN_USE=$(aws ec2 describe-instances \
            --filters Name=private-ip-address,Values=$TARGET_IP \
            --query 'Reservations[].Instances[].InstanceId' \
            $AWS_OPTS)
        
        if [ -z "$IP_IN_USE" ]; then
            IPS+=($TARGET_IP)
            log_info "Available IP: $TARGET_IP"
        else
            log_warning "IP $TARGET_IP is in use by instance $IP_IN_USE"
        fi
    done
    
    if [ ${#IPS[@]} -lt 3 ]; then
        log_error "Not enough available IPs found. Needed 3, found ${#IPS[@]}"
    fi
    
    CONTROL_PLANE_IP=${IPS[0]}
    WORKER1_IP=${IPS[1]}
    WORKER2_IP=${IPS[2]}
}

# Create security group
create_security_group() {
    log_info "Creating security group 'Kube-ADM'..."
    
    EXISTING_SG=$(aws ec2 describe-security-groups \
        --filters Name=group-name,Values=Kube-ADM Name=vpc-id,Values=$DEFAULT_VPC \
        --query 'SecurityGroups[0].GroupId' \
        $AWS_OPTS)
    
    if [ "$EXISTING_SG" != "None" ]; then
        log_info "Security group 'Kube-ADM' already exists: $EXISTING_SG"
        SG_ID=$EXISTING_SG
    else
        SG_ID=$(aws ec2 create-security-group \
            --group-name "Kube-ADM" \
            --description "Kubernetes ADM Security Group" \
            --vpc-id $DEFAULT_VPC \
            --query 'GroupId' \
            $AWS_OPTS)
        log_info "Created security group: $SG_ID"
    fi
    
    log_info "Configuring security group rules..."
    
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 22 \
        --cidr $MY_IP \
        $AWS_OPTS 2>/dev/null || log_warning "SSH rule may already exist"
    
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 6443 \
        --cidr 0.0.0.0/0 \
        $AWS_OPTS 2>/dev/null || log_warning "API Server rule may already exist"
    
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 2379-2380 \
        --source-group $SG_ID \
        $AWS_OPTS 2>/dev/null || log_warning "etcd rule may already exist"
    
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 10250 \
        --source-group $SG_ID \
        $AWS_OPTS 2>/dev/null || log_warning "Kubelet rule may already exist"
    
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 10259 \
        --source-group $SG_ID \
        $AWS_OPTS 2>/dev/null || log_warning "Scheduler rule may already exist"
    
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 10257 \
        --source-group $SG_ID \
        $AWS_OPTS 2>/dev/null || log_warning "Controller rule may already exist"
    
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 30000-32767 \
        --cidr 0.0.0.0/0 \
        $AWS_OPTS 2>/dev/null || log_warning "NodePort rule may already exist"
}

# Create instances
create_instances() {
    log_info "Creating Kubernetes instances..."
    
    INSTANCE_SPECS=(
        "k8s-control-plane:$CONTROL_PLANE_IP"
        "k8s-worker-1:$WORKER1_IP"
        "k8s-worker-2:$WORKER2_IP"
    )
    
    INSTANCE_JSON="["
    
    for spec in "${INSTANCE_SPECS[@]}"; do
        IFS=':' read -r INSTANCE_NAME PRIVATE_IP <<< "$spec"
        
        log_info "Creating $INSTANCE_NAME with IP $PRIVATE_IP..."
        
        INSTANCE_ID=$(aws ec2 run-instances \
            --image-id $IMAGE_ID \
            --instance-type $INSTANCE_TYPE \
            --key-name $KEY_NAME \
            --security-group-ids $SG_ID \
            --subnet-id $DEFAULT_SUBNET \
            --private-ip-address $PRIVATE_IP \
            --associate-public-ip-address \
            --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":$DISK_SIZE,\"VolumeType\":\"$DISK_TYPE\"}}]" \
            --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
            --query 'Instances[0].InstanceId' \
            $AWS_OPTS)
        
        if [ "$INSTANCE_JSON" != "[" ]; then
            INSTANCE_JSON+=","
        fi
        
        INSTANCE_JSON+="{\"name\":\"$INSTANCE_NAME\",\"id\":\"$INSTANCE_ID\",\"private_ip\":\"$PRIVATE_IP\"}"
        
        log_info "Created $INSTANCE_NAME: $INSTANCE_ID"
    done
    
    INSTANCE_JSON+="]"
    
    echo -e "\n${GREEN}Instance Creation Summary:${NC}"
    echo $INSTANCE_JSON | python3 -m json.tool 2>/dev/null || echo $INSTANCE_JSON
}

# Check AWS profile
check_aws_profile() {
    log_info "Checking AWS profile: $AWS_PROFILE"
    
    if ! aws sts get-caller-identity --profile $AWS_PROFILE &> /dev/null; then
        log_error "AWS profile '$AWS_PROFILE' not configured or invalid. Available profiles:"
        aws configure list-profiles 2>/dev/null || log_error "No AWS profiles found. Run 'aws configure' first."
        exit 1
    fi
    
    log_info "AWS profile '$AWS_PROFILE' is valid"
    log_info "Account details:"
    aws sts get-caller-identity --profile $AWS_PROFILE --output text | awk '{print "Account:", $1; print "User ID:", $2; print "ARN:", $3}'
}

# Main execution
main() {
    log_info "Starting Kubernetes cluster provisioning..."
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
    fi
    
    # Check AWS profile
    check_aws_profile
    
    get_default_vpc
    get_default_subnet
    find_available_ips
    create_security_group
    create_instances
    
    log_info "Kubernetes cluster provisioning completed successfully using profile: $AWS_PROFILE!"
    log_info "Wait a few minutes for instances to initialize, then SSH using:"
    log_info "ssh -i your-key.pem ubuntu@<public-ip>"
}

main "$@"