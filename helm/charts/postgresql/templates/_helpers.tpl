{{/*
Expand the name of the chart.
*/}}
{{- define "postgresql.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Create a fullname using the release name and the chart name.
*/}}
{{- define "postgresql.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else }}
{{- $name := include "postgresql.name" . }}
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
{{- define "postgresql.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "postgresql.labels" -}}
helm.sh/chart: {{ include "postgresql.chart" . }}
{{ include "postgresql.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "postgresql.selectorLabels" -}}
app.kubernetes.io/name: {{ include "postgresql.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the secret to use for database credentials
*/}}
{{- define "postgresql.secretName" -}}
{{- if .Values.existingSecret }}
{{- .Values.existingSecret }}
{{- else }}
{{- include "postgresql.fullname" . }}-credentials
{{- end }}
{{- end }}

{{/*
Create the name of the cluster
*/}}
{{- define "postgresql.clusterName" -}}
{{- include "postgresql.fullname" . }}
{{- end }}

{{/*
Create the full image reference
Force tag to string to handle numeric values like "17" passed as integers
*/}}
{{- define "postgresql.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | toString) }}
{{- end }}

{{/*
Create the primary service name (CNPG creates this automatically)
*/}}
{{- define "postgresql.primaryServiceName" -}}
{{- include "postgresql.clusterName" . }}-rw
{{- end }}

{{/*
Create the replica service name (CNPG creates this automatically)
*/}}
{{- define "postgresql.replicaServiceName" -}}
{{- include "postgresql.clusterName" . }}-ro
{{- end }}

{{/*
Create the any instance service name (CNPG creates this automatically)
*/}}
{{- define "postgresql.anyServiceName" -}}
{{- include "postgresql.clusterName" . }}-r
{{- end }}

{{/*
Generate postgresql.conf parameters as YAML
Note: shared_preload_libraries cannot be set via CNPG parameters -
it's managed at the container/image level. The calltelemetry/postgres
image already has timescaledb and pg_ivm configured.
*/}}
{{- define "postgresql.parameters" -}}
{{- range $key, $value := .Values.cluster.postgresql.parameters }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}

{{/*
Create the S3 credentials secret name for backups
*/}}
{{- define "postgresql.backupSecretName" -}}
{{- if .Values.backup.s3.existingSecret }}
{{- .Values.backup.s3.existingSecret }}
{{- else }}
{{- include "postgresql.fullname" . }}-backup-s3
{{- end }}
{{- end }}
