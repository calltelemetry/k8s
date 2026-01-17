{{/*
Expand the name of the chart.
*/}}
{{- define "jtapi-sidecar.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Create a fullname using the release name and the chart name.
*/}}
{{- define "jtapi-sidecar.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else }}
{{- $name := include "jtapi-sidecar.name" . }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "jtapi-sidecar.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "jtapi-sidecar.labels" -}}
helm.sh/chart: {{ include "jtapi-sidecar.chart" . }}
{{ include "jtapi-sidecar.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "jtapi-sidecar.selectorLabels" -}}
app.kubernetes.io/name: {{ include "jtapi-sidecar.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the CUCM secret to use
*/}}
{{- define "jtapi-sidecar.cucmSecretName" -}}
{{- if .Values.cucm.existingSecret }}
{{- .Values.cucm.existingSecret }}
{{- else }}
{{- include "jtapi-sidecar.fullname" . }}-cucm
{{- end }}
{{- end }}

{{/*
Create the name of the WebSocket secret to use
*/}}
{{- define "jtapi-sidecar.websocketSecretName" -}}
{{- if .Values.websocket.existingSecret }}
{{- .Values.websocket.existingSecret }}
{{- else }}
{{- include "jtapi-sidecar.fullname" . }}-websocket
{{- end }}
{{- end }}
