{{- define "django-app.name -}}  #start : declare the variable_name as we want 
{{- .Chart.Name -}}              #value comes from chart.yaml file => (.name )
{{- end -}}                      #end : 


# Already define "django-app.name", now we can use this define value with the help of "include" function {{ include "django-app.name" . }} <- this last dot (.) recieves the current context

{{- define "django-app.fullname" -}} #start : declare the variable_name as we want
{{- printf "%s-%s" .Release.Name (include "django-app.name" .) | trunc 63 | trimSuffix "-" -}} #value comes from file of release.name and chart.name
{{- end -}}

#%s -> this is used for string formatting(print value). here first %s is for .Release.Name and second %s is for (include "django-app.name" .)