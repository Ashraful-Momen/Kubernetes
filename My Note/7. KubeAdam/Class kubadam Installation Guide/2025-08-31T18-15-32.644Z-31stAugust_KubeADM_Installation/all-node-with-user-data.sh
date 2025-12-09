#!/bin/bash
# Kubernetes Installation Script with Error Handling and Logging
set -e

# Configuration
LOG_FILE="/var/log/kubernetes-install.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
CONTAINERD_CONFIG="/etc/containerd/config.toml"
KUBERNETES_KEYRING="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
KUBERNETES_LIST="/etc/apt/sources.list.d/kubernetes.list"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    echo "$TIMESTAMP [INFO] $1" >> "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "$TIMESTAMP [WARN] $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "$TIMESTAMP [ERROR] $1" >> "$LOG_FILE"
    exit 1
}

# Function to check command success
check_success() {
    if [ $? -eq 0 ]; then
        log_info "$1 completed successfully"
    else
        log_error "$1 failed. Check $LOG_FILE for details."
    fi
}

# Function to run command with error handling
run_cmd() {
    local cmd="$1"
    local description="$2"
    
    log_info "Starting: $description"
    echo "$TIMESTAMP [CMD] $cmd" >> "$LOG_FILE"
    
    # Execute command and capture both stdout and stderr
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        log_info "$description completed successfully"
    else
        log_error "$description failed. Exit code: $?"
    fi
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root. Please use sudo."
    fi
}

# Function to check internet connectivity
check_internet() {
    log_info "Checking internet connectivity..."
    if ! ping -c 1 -W 2 google.com >/dev/null 2>&1; then
        if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
            log_warning "No internet connectivity detected. Some operations may fail."
        fi
    fi
}

# Function to setup system prerequisites
setup_prerequisites() {
    log_info "Setting up system prerequisites for Kubernetes"
    
    # Disable swap
    run_cmd "swapoff -a" "Disable swap"
    run_cmd "sed -i '/ swap / s/^\\(.*\\)$/#\\1/g' /etc/fstab" "Comment out swap in fstab"
    
    # Load kernel modules
    run_cmd "echo 'overlay' | tee /etc/modules-load.d/containerd.conf" "Add overlay module to modules-load"
    run_cmd "echo 'br_netfilter' | tee -a /etc/modules-load.d/containerd.conf" "Add br_netfilter module to modules-load"
    run_cmd "modprobe overlay" "Load overlay kernel module"
    run_cmd "modprobe br_netfilter" "Load br_netfilter kernel module"
    
    # Configure sysctl for Kubernetes networking
    run_cmd "echo 'net.bridge.bridge-nf-call-iptables = 1' | tee /etc/sysctl.d/99-kubernetes-cri.conf" "Configure iptables bridge calls"
    run_cmd "echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.d/99-kubernetes-cri.conf" "Configure IP forwarding"
    run_cmd "echo 'net.bridge.bridge-nf-call-ip6tables = 1' | tee -a /etc/sysctl.d/99-kubernetes-cri.conf" "Configure ip6tables bridge calls"
    
    # Apply sysctl params
    run_cmd "sysctl --system" "Apply sysctl parameters"
}

# Main installation function
install_kubernetes() {
    log_info "Starting Kubernetes installation process"
    log_info "Log file: $LOG_FILE"
    
    # Check prerequisites
    check_root
    check_internet
    
    # Setup system prerequisites
    setup_prerequisites
    
    # Update package lists
    run_cmd "apt-get update" "Update package lists"
    
    # Install containerd
    run_cmd "apt-get install -y containerd" "Install containerd"
    
    # Create containerd directory if it doesn't exist
    if [ ! -d "/etc/containerd" ]; then
        run_cmd "mkdir -p /etc/containerd" "Create containerd config directory"
    fi
    
    # Generate containerd default config
    if command -v containerd >/dev/null 2>&1; then
        run_cmd "containerd config default | tee $CONTAINERD_CONFIG" "Generate containerd default configuration"
    else
        log_error "containerd command not found after installation"
    fi
    
    # Enable systemd cgroups
    if [ -f "$CONTAINERD_CONFIG" ]; then
        run_cmd "sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' $CONTAINERD_CONFIG" "Enable systemd cgroups in containerd config"
    else
        log_error "Containerd config file not found: $CONTAINERD_CONFIG"
    fi
    
    # Restart and enable containerd
    run_cmd "systemctl restart containerd" "Restart containerd service"
    run_cmd "systemctl enable containerd" "Enable containerd service"
    run_cmd "systemctl status containerd --no-pager -l" "Check containerd status"
    
    # Install additional packages
    run_cmd "apt-get install -y apt-transport-https ca-certificates curl gpg" "Install required packages"
    
    # Create keyrings directory
    if [ ! -d "/etc/apt/keyrings" ]; then
        run_cmd "mkdir -p /etc/apt/keyrings" "Create apt keyrings directory"
    fi
    
    # Add Kubernetes GPG key
    run_cmd "curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o $KUBERNETES_KEYRING" "Add Kubernetes GPG key"
    
    # Add Kubernetes repository
    run_cmd "echo 'deb [signed-by=$KUBERNETES_KEYRING] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | tee $KUBERNETES_LIST" "Add Kubernetes repository"
    
    # Update package lists again
    run_cmd "apt-get update" "Update package lists with Kubernetes repo"
    
    # Install Kubernetes components
    run_cmd "apt-get install -y kubelet kubeadm kubectl" "Install Kubernetes components (kubelet, kubeadm, kubectl)"
    
    # Hold packages to prevent accidental upgrades
    run_cmd "apt-mark hold kubelet kubeadm kubectl" "Hold Kubernetes packages to prevent auto-upgrade"
    
    # Verify installations (using compatible commands)
    run_cmd "containerd --version" "Verify containerd installation"
    run_cmd "kubelet --version" "Verify kubelet installation"
    run_cmd "kubectl version --client" "Verify kubectl installation"  # Fixed: removed --short flag
    run_cmd "kubeadm version" "Verify kubeadm installation"
    
    # Additional verification
    run_cmd "which kubectl kubelet kubeadm" "Verify binary locations"
    run_cmd "ls -la /usr/bin/kubectl /usr/bin/kubelet /usr/bin/kubeadm" "Verify binary permissions"
    
    log_info "Kubernetes installation completed successfully!"
    log_info "Next steps:"
    log_info "1. Initialize cluster with: kubeadm init"
    log_info "2. Set up kubectl config: mkdir -p \$HOME/.kube && cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config"
    log_info "3. Install network plugin (Calico, Flannel, etc.)"
}

# Cleanup function (optional)
cleanup() {
    log_info "Cleaning up temporary files..."
    # Add any cleanup operations here if needed
}

# Trap signals for cleanup
trap cleanup EXIT INT TERM

# Main execution
main() {
    log_info "=== Kubernetes Installation Script Started ==="
    
    # Check if log directory exists
    if [ ! -d "/var/log" ]; then
        mkdir -p /var/log
    fi
    
    # Create log file
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    # Run installation
    install_kubernetes
    
    log_info "=== Kubernetes Installation Script Completed ==="
    echo -e "${GREEN}Installation completed successfully! Check $LOG_FILE for details.${NC}"
}

# Run main function
main "$@"