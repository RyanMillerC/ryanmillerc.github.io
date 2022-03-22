---
layout: post
title:  "Kuberentes-Managed TLS Certificates with cert-manager"
---

I use sub-domains of `taco.moe` for everything in my homelab. One reason I do this is because I want valid [TLS](https://en.wikipedia.org/wiki/Public_key_certificate) certificates (don't want to deal with self-signed certs or manage a CA). 😅

[Let's Encrypt](https://letsencrypt.org) provides free TLS certificates to anyone who can prove they own the domain they're requesting a certificate for. Domain validation is done through a *challenge*, either HTTP-based (host a file on your domain) or DNS-based (create a [TXT](https://en.wikipedia.org/wiki/TXT_record) record).

The only downside to Let's Encrypt is that issued certificates are only valid for 90 days. Thankfully there is an automated process to request certificates from Let's Encrypt: *cert-manager*.

[cert-manager](https://cert-manager.io) is a cloud-native certificate management solution that runs on Kubernetes. It provides CRDs for requesting and issuing certificates and automatically keeps the issued certificates up to date.

## Anatomy of cert-manager

At a high level, the certificate provisioning process with cert-manager looks like this:

```
Issuer (ClusterIssuer) -> Certificate -> Secret (kubernetes.io/tls)
```

cert-manager uses an Issuer to handle certificate provisioning. There are two types of issuer: `Issuer` (namespaced) and `ClusterIssuer` (issue certificates to any namespace). For each TLS certificate, I create a `Certificate` instance. cert-manager handles requesting the TLS certificate from Let's Encrypt when a `Certificate` instance is created. Once Let's Encrypt has completed it's challenge and signed the TLS certificate, cert-manager creates a TLS-type `Secret` with the certificate/key as key-value pairs. The secret can then be mounted by `Pods`.

**NOTE:** There are additional resources created by cert-manager automatically during the certificate provisioning process. Unless there are errors, I never need to touch these. If you do need to troubleshoot, [this diagram](https://cert-manager.io/docs/concepts/certificate/#certificate-lifecycle) shows all K8s custom resource relationships.

## My cert-manager Deployment

I have cert-manager running on a [k3s](https://k3s.io) deployment on my home network managing all of my TLS certificates.

My lab runs on private IP space and isn't exposed externally. DNS for `taco.moe` is split into internal and external zones. The internal zone is hosted on a private nameserver in my home network. The external zone is on AWS Route 53 (which points to Netlify, aka this site). Here's a quick diagram:

```text
+-------------------------------+-----------------------+
|            Internal           |        External       |
|-------------------------------+-----------------------+
| git.taco.moe      -> 10.0.2.2 | taco.moe -> 75.2.60.5 |
| whatever.taco.moe -> 10.0.2.3 |                       |
+-------------------------------+-----------------------+
```

**I'm able to use cert-manager with DNS challenge even though none of my sub-domains have any public records.** I only need be able manipulate TXT records in my public zone (Route 53) to prove I own the TLD. cert-manager can create these TXT records using an AWS IAM service account.

## Provisioning Certs with cert-manager

**NOTE:** Everything below is based on my configuration: cert-manager running on k3s, provisioning certificates from Let's Encrypt for sub-domains of my TLD, `taco.moe`, by performing DNS-based challenges against Route 53, my external DNS zone.

### Install cert-manager

First, install cert-manager. [The docs](https://cert-manager.io/docs/installation/) have great instructions depending on your platform. I'm running on k3s and used the `kubectl apply` method. I've also had success installing with the cert-manager operator on OpenShift.

### Create Namespace

Check if the installation created the `cert-manager` namespace. If the installation didn't do this for you, create it:

```bash
$ kubectl create namespace cert-manager
```

### Create AWS IAM Service Account

Create an IAM service account in the AWS console with [these instructions](https://cert-manager.io/docs/configuration/acme/dns01/route53/) from the cert-manager docs. Note the account access key and secret access key, they will be required for the next few steps.

### Create AWS Service Account Secret

Create a secret to hold the AWS secret access key:

* **Replace value on line marked with `# Replace me`.**
* `stringData` in a Secret manifest will base64 encode the given strings and set the `data` field with the encoded value in the created Secret object.

```yaml
cat << EOF | oc apply -f -
apiVersion: v1
stringData:
  secret-access-key: REDACTED # Replace me
kind: Secret
metadata:
  name: aws-secret
  namespace: cert-manager
type: Opaque
EOF
```

### Create ClusterIssuer

Create the ClusterIssuer:

* **Replace values on lines marked with `# Replace me`**
* `secretAccessKeySecretRef` points to the previously created secret in the `cert-manager` namespace
* `accessKeyID` is the access key of the AWS IAM service account
* `privateKeySecretRef` is used to store the ACME account's private key (secret will be created, it should not exist)

```yaml
cat << EOF | oc apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: cluster-cert-issuer
spec:
  acme:
    email: REDACTED # Replace me
    preferredChain: ""
    privateKeySecretRef:
      name: cluster-cert-issuer-secret
    server: https://acme-v02.api.letsencrypt.org/directory
    solvers:
    - dns01:
        route53:
          accessKeyID: REDACTED # Replace me
          region: us-east-1
          secretAccessKeySecretRef:
            key: secret-access-key
            name: aws-secret
      selector:
        dnsZones:
        - taco.moe # Replace me
EOF
```

### Create a Certificate

Create the first managed certificate:

* **Replace values on lines marked with `# Replace me`**
* This object can be placed in any namespace, it doesn't have to be in cert-manager
* Certificate issuing status can checked with `kubectl get certs` under the `Ready` column (it may take a few minutes for the challenge to complete)
* `secretName` is the secret cert-manager should create with the new TLS certificate (secret will be created, it should not exist)

```yaml
cat << EOF | oc apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: taco-moe-cert # Replace me
  namespace: kube-system # Replace me
spec:
  commonName: taco.moe
  dnsNames:
  - git.taco.moe # Replace me
  # - '*.taco.moe' # Example wildcard
  issuerRef:
    kind: ClusterIssuer
    name: cluster-cert-issuer
  secretName: taco-moe-tls # Replace me
EOF
```

*[CA]: Certificate Authority
*[CRD]: Custom Resource Definition
*[TLD]: Top-Level Domain
