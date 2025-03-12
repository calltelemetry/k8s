{{/* Generate service account name */}}
{{- define "ingress.serviceAccountName" -}}
{{- printf "ingress-controller-%s" .Release.Namespace -}}
{{- end -}}

{{/* Generate ingress controller selector */}}
{{- define "ingress.controllerSelector" -}}
app.kubernetes.io/name: {{ index .Values "ingress-controller" "selector" "name" }}
{{- end -}}
