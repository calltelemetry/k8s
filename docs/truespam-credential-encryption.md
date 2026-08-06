# TrueSpam credential encryption

The API chart projects the TrueSpam encryption key from an operator-managed
Kubernetes Secret. It projects only the key version and the Demo legal gate
from a ConfigMap. Do not put the encryption key in Helm values, a ConfigMap, a
Deployment manifest, or source control.

Create the Secret out of band in the target namespace:

```sh
kubectl -n ct-prod create secret generic truespam-credential-encryption \
  --from-literal=encryption-key="$(openssl rand -hex 32)"
```

Enable the chart in the environment API values file only after the Secret
exists:

```yaml
truespam:
  enabled: true
  existingSecretName: truespam-credential-encryption
  existingSecretKey: encryption-key
  keyVersion: v1
  demoLimitsLegalConfirmed: false
```

During key rotation, keep the old ciphertext-decryption key in the same
Secret and list it under `retainedKeys` until all stored credentials have
been re-encrypted:

```yaml
truespam:
  keyVersion: v2
  existingSecretKey: encryption-key
  retainedKeys:
    - version: v1
      secretKey: encryption-key-v1
```

The application reads retained keys as
`TRUESPAM_CREDENTIAL_ENCRYPTION_KEY_<version>`. Remove an old Secret key only
after no credential records reference that encryption key version.
