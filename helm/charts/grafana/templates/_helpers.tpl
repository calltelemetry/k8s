{{/*
Expand the name of the chart.
*/}}
{{- define "grafana.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Create a fullname using the release name and the chart name.
*/}}
{{- define "grafana.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else }}
{{- $name := include "grafana.name" . }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "grafana.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "grafana.labels" -}}
helm.sh/chart: {{ include "grafana.chart" . }}
{{ include "grafana.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "grafana.selectorLabels" -}}
app.kubernetes.io/name: {{ include "grafana.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: {{ include "grafana.fullname" . }}
{{- end }}

{{/*
Prometheus URL - auto-detect if not specified
*/}}
{{- define "grafana.prometheusUrl" -}}
{{- if .Values.datasources.prometheus.url }}
{{- .Values.datasources.prometheus.url }}
{{- else }}
{{- printf "http://prometheus.%s.svc.cluster.local:9090" .Release.Namespace }}
{{- end }}
{{- end }}

{{/*
Tempo URL - auto-detect if not specified
*/}}
{{- define "grafana.tempoUrl" -}}
{{- if .Values.datasources.tempo.url }}
{{- .Values.datasources.tempo.url }}
{{- else }}
{{- printf "http://tempo.%s.svc.cluster.local:3200" .Release.Namespace }}
{{- end }}
{{- end }}

{{/*
Loki URL - auto-detect if not specified
*/}}
{{- define "grafana.lokiUrl" -}}
{{- if .Values.datasources.loki.url }}
{{- .Values.datasources.loki.url }}
{{- else }}
{{- printf "http://loki.%s.svc.cluster.local:3100" .Release.Namespace }}
{{- end }}
{{- end }}

{{/*
Dashboard ConfigMap name
Uses external ConfigMap if specified, otherwise the chart-generated one
*/}}
{{- define "grafana.dashboardsConfigMap" -}}
{{- if .Values.dashboards.externalConfigMap }}
{{- .Values.dashboards.externalConfigMap }}
{{- else }}
{{- include "grafana.fullname" . }}-dashboards
{{- end }}
{{- end }}
