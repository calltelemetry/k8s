{{- define "ksm.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}
{{- define "ksm.fullname" -}}
{{- if .Values.fullnameOverride -}}{{ .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}{{- else -}}{{ include "ksm.name" . }}{{- end -}}
{{- end }}
{{- define "ksm.labels" -}}
app.kubernetes.io/name: {{ include "ksm.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end }}

{{/*
Cluster-scoped RBAC names include the namespace so the managed replacement can
coexist with the legacy kube-system kube-state-metrics installation.
*/}}
{{- define "ksm.clusterRoleName" -}}
{{- printf "%s-%s" .Release.Namespace (include "ksm.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}
