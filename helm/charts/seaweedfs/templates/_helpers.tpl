{{/*
Expand the name of the chart.
*/}}
{{- define "seaweedfs.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Create a fullname using the release name and the chart name.
*/}}
{{- define "seaweedfs.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else }}
{{- $name := include "seaweedfs.name" . }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "seaweedfs.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "seaweedfs.labels" -}}
helm.sh/chart: {{ include "seaweedfs.chart" . }}
{{ include "seaweedfs.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "seaweedfs.selectorLabels" -}}
app.kubernetes.io/name: {{ include "seaweedfs.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: {{ include "seaweedfs.fullname" . }}
{{- end }}

{{/*
Create the name of the secret to use
*/}}
{{- define "seaweedfs.secretName" -}}
{{- if .Values.auth.existingSecret }}
{{- .Values.auth.existingSecret }}
{{- else }}
{{- include "seaweedfs.fullname" . }}-credentials
{{- end }}
{{- end }}
