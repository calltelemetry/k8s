{{/* Common name + labels for the ct-uat-job chart. */}}

{{- define "ct-uat-job.name" -}}
{{- default "ct-uat-job" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ct-uat-job.labels" -}}
app.kubernetes.io/name: ct-uat-job
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: preview-uat
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{- define "ct-uat-job.selectorLabels" -}}
app.kubernetes.io/name: ct-uat-job
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
