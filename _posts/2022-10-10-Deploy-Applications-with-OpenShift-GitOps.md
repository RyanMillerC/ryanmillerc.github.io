---
layout: post
title:  "Deploy Applications with OpenShift GitOps (Argo CD)"
---

{% raw %}

OpenShift GitOps is a Red Hat supported Operator that deploys Argo CD on an
OpenShift Container Platform (OCP) cluster. This post breaks down how to set up
OpenShift GitOps to continously deploy manifests from a Git repo to an
OpenShift namespace.

## Installing OpenShift GitOps

**OpenShift GitOps is a one click installation. 🎉**

In OpenShift, navigate to Operator Hub - Search for OpenShift GitOps - Install
the operator with the defaults.

![Operator Hub, filtered for "OpenShift GitOps"](/assets/2022-10-10-Deploy-Applications-with-OpenShift-GitOps/operator-hub.png)

The operator will create a cluster Argo CD instance capable of managing namespaces (OCP projects) matching the label `argocd.argoproj.io/managed-by: openshift-gitops`. The cluster Argo CD instance is deployed to the  *openshift-gitops* namespace/project.

It may take a few minutes for the Argo CD instance to become available. Once the pods in the *openshift-gitops* namespace are *Ready*, you can navigate to the Argo CD console through the "Cluster Argo CD" link in the application menu.

![How to navigate to the Argo CD console](/assets/2022-10-10-Deploy-Applications-with-OpenShift-GitOps/cluster-argo-cd.png)

The remainder of this post is an [Example GitOps Repo] I put together, commit by commit. It’s always a good idea to start a project in a Git repo and commit **(and push!)** incrementally.

## Add example theme-park-api Helm chart ([8011d79])

```diff
commit 8011d798f3792199107ad3cd995f26e245425b71
Author: Ryan Miller <miller@redhat.com>
Date:   Mon Oct 10 20:59:08 2022 -0400

    Add example theme-park-api Helm chart

diff --git a/hershey-park/Chart.yaml b/hershey-park/Chart.yaml
new file mode 100644
index 0000000..df760d1
--- /dev/null
+++ b/hershey-park/Chart.yaml
@@ -0,0 +1,5 @@
+apiVersion: v2
+name: theme-park-api
+description: Example Spring REST API deployed through a Helm Chart
+type: application
+version: 0.1.0
diff --git a/hershey-park/templates/deployment.yaml b/hershey-park/templates/deployment.yaml
new file mode 100644
index 0000000..a1f8c89
--- /dev/null
+++ b/hershey-park/templates/deployment.yaml
@@ -0,0 +1,24 @@
+{{ range .Values.applications }}
+---
+apiVersion: apps/v1
+kind: Deployment
+metadata:
+  name: "{{ $.Release.Name }}-{{ .name }}"
+spec:
+  selector:
+    matchLabels:
+      app: "{{ $.Release.Name }}-{{ .name }}"
+  replicas: {{ $.Values.replicaCount }}
+  template:
+    metadata:
+      labels:
+        app: "{{ $.Release.Name }}-{{ .name }}"
+    spec:
+      containers:
+      - name: "{{ $.Release.Name }}-{{ .name }}"
+        image: "{{ .image }}"
+        imagePullPolicy: Always
+        ports:
+        - containerPort: 8080
+          protocol: "TCP"
+{{ end }}
diff --git a/hershey-park/templates/ingress.yaml b/hershey-park/templates/ingress.yaml
new file mode 100644
index 0000000..679e835
--- /dev/null
+++ b/hershey-park/templates/ingress.yaml
@@ -0,0 +1,22 @@
+{{ range .Values.applications }}
+---
+apiVersion: networking.k8s.io/v1
+kind: Ingress
+metadata:
+  annotations:
+    route.openshift.io/termination: edge
+    haproxy.router.openshift.io/rewrite-target: '/'
+  name: "{{ $.Release.Name }}-{{ .name }}"
+spec:
+  rules:
+  - host: "{{ $.Values.dnsName }}"
+    http:
+      paths:
+      - path: /
+        pathType: Prefix
+        backend:
+          service:
+            name: "{{ $.Release.Name }}-{{ .name }}"
+            port:
+              number: 8080
+{{ end }}
diff --git a/hershey-park/templates/service.yaml b/hershey-park/templates/service.yaml
new file mode 100644
index 0000000..286206e
--- /dev/null
+++ b/hershey-park/templates/service.yaml
@@ -0,0 +1,14 @@
+{{ range .Values.applications }}
+---
+apiVersion: v1
+kind: Service
+metadata:
+  name: "{{ $.Release.Name }}-{{ .name }}"
+spec:
+  ports:
+    - targetPort: 8080
+      port: 8080
+      protocol: TCP
+  selector:
+    app: "{{ $.Release.Name }}-{{ .name }}"
+{{ end }}
diff --git a/hershey-park/values.yaml b/hershey-park/values.yaml
new file mode 100644
index 0000000..8b9f73d
--- /dev/null
+++ b/hershey-park/values.yaml
@@ -0,0 +1,9 @@
+# Replicas of each application
+replicaCount: 1
+
+# Domain the application will be served from
+dnsName: hershey-park-dev.apps.dev.taco.moe
+
+applications:
+  - name: hershey-park-dev
+    image: quay.io/rymiller/theme-park-api:hershey-park
```

This commit adds a Helm chart for the example *theme-park-api* application.
This will be deployed to the cluster using Argo CD in later commits.

**The contents of this chart don't matter!** If you don't know Helm, that's ok.
The only purpose of this chart is to have an example application to deploy with
Argo.

(**Bonus:** Check out [Writing Helm Charts isn't hard] for a primer on Helm.)

## Add namespace for theme-park-api under ./gitops ([7c226e5])

```diff
commit 7c226e5e3d78d9bcd64a3aba2f903d579ba10911
Author: Ryan Miller <miller@redhat.com>
Date:   Mon Oct 10 21:02:07 2022 -0400

    Add namespace for theme-park-api under ./gitops

diff --git a/gitops/README.md b/gitops/README.md
new file mode 100644
index 0000000..37d5092
--- /dev/null
+++ b/gitops/README.md
@@ -0,0 +1 @@
+# Argo CD manifests to deploy theme-park-api
diff --git a/gitops/manifests/01-namespace.yaml b/gitops/manifests/01-namespace.yaml
new file mode 100644
index 0000000..0f46f0d
--- /dev/null
+++ b/gitops/manifests/01-namespace.yaml
@@ -0,0 +1,6 @@
+apiVersion: v1
+kind: Namespace
+metadata:
+  labels:
+    argocd.argoproj.io/managed-by: openshift-gitops
+  name: theme-park-api
```

Argo will deploy the example application into this namespace. Deploying this
YAML manifest will create a corresponding OpenShift project.

It's important that the label `argocd.argoproj.io/managed-by: openshift-gitops`
be present on any namespace Argo CD is deploying into. If it's not labeled,
Argo CD will error when it tries to deploy resources into a namespace.

## Add AppProject for theme-park-api ([cdff420])

```diff
commit cdff420d34b281e0197475cda9e1474c9b9fb2ac
Author: Ryan Miller <miller@redhat.com>
Date:   Mon Oct 10 21:03:03 2022 -0400

    Add AppProject for theme-park-api

diff --git a/gitops/manifests/02-app-project.yaml b/gitops/manifests/02-app-project.yaml
new file mode 100644
index 0000000..8754531
--- /dev/null
+++ b/gitops/manifests/02-app-project.yaml
@@ -0,0 +1,11 @@
+apiVersion: argoproj.io/v1alpha1
+kind: AppProject
+metadata:
+  name: theme-park-api
+  namespace: openshift-gitops
+spec:
+  destinations:
+    - name: in-cluster
+      namespace: theme-park-api
+  sourceRepos:
+    - https://github.com/RyanMillerC/deploy-with-openshift-gitops.git
```

An Argo CD AppProject is a group of applications that Argo CD manages. It is
similar to a Kubernetes Namespace (OpenShift Project) and contains metadata
about the group of applications.

My take is that an Argo CD AppProject should match 1:1 with the
namespace/project it's deploying into in OpenShift. Any applications deployed
into the same namespace should be included in the same AppProject.

One important note about *sourceRepos*: **Every Argo CD application must be
deployed from a repo that matches one of the defined AppProject sourceRepos.**
It does support wildcards!

## Add Argo CD Application for Hershey Park ([faf7545])

```diff
commit faf7545d8e466c17ebd6fbc90dc908a99b6f4899
Author: Ryan Miller <miller@redhat.com>
Date:   Mon Oct 10 21:05:54 2022 -0400

    Add Argo CD Application for Hershey Park

diff --git a/gitops/manifests/03-application.yaml b/gitops/manifests/03-application.yaml
new file mode 100644
index 0000000..b4561d0
--- /dev/null
+++ b/gitops/manifests/03-application.yaml
@@ -0,0 +1,26 @@
+apiVersion: argoproj.io/v1alpha1
+kind: Application
+metadata:
+  name: hershey-park
+  namespace: openshift-gitops
+spec:
+  destination:
+    name: in-cluster
+    namespace: theme-park-api
+  project: theme-park-api # Argo CD AppProject
+  source:
+    directory:
+      # This is necessary if you have multiple directories in a repo and only
+      # want to deploy a single directory
+      recurse: false
+    path: ./hershey-park
+    repoURL: https://github.com/RyanMillerC/deploy-with-openshift-gitops.git
+    targetRevision: main # Argo will default to `master`
+  # These sync policy settings allow Argo to prune outdated resoruces and fix
+  # resources that might be missing.
+  syncPolicy:
+    automated:
+      prune: true
+      selfHeal: true
+    syncOptions:
+      - PruneLast=true
```

An Argo CD *Application* contains configurations for a single application that
Argo CD manages. It includes the Git repo URL, Git branch to deploy, OpenShift
namespace to deploy into, etc. The Git repo for the application being deployed
can contain straight YAML manifests, Kustomize, or Helm charts.

At this point, I'm able to continuously deploy the application with Argo CD! To
deploy, I'll create the manifests under *./gitops/manifests* with:

```bash
$ oc create -f ./gitops/manifests
namespace/theme-park-api created
appproject.argoproj.io/theme-park-api created
application.argoproj.io/hershey-park created
```

If I log into the cluster Argo CD instance web console, I see this the
application syncing and eventually it returns *Healthy* and *synced*.

![Application is "Healthy" and "Synced" in Argo CD console](assets/2022-10-10-Deploy-Applications-with-OpenShift-GitOps/application-deployed.png)

Clicking on the application card shows a topology view of resources deployed to
the cluster.

![Application topology of all resources that Argo CD has deployed](assets/2022-10-10-Deploy-Applications-with-OpenShift-GitOps/application-topology.png)

## Generalize Helm chart and Argo CD Application ([f76e2d1])

```diff
commit f76e2d1948753f1e7fbbe7082bdead98e2445896
Author: Ryan Miller <miller@redhat.com>
Date:   Mon Oct 10 21:21:58 2022 -0400

    Generalize Helm chart and Argo CD Application

    Move ./hershey-park to ./theme-park-api. Update Argo CD to point to new
    location. Update Argo CD to use a different values.yaml file.

diff --git a/gitops/manifests/03-application.yaml b/gitops/manifests/03-application.yaml
index b4561d0..b695ed6 100644
--- a/gitops/manifests/03-application.yaml
+++ b/gitops/manifests/03-application.yaml
@@ -13,7 +13,10 @@ spec:
       # This is necessary if you have multiple directories in a repo and only
       # want to deploy a single directory
       recurse: false
-    path: ./hershey-park
+    helm:
+      valueFiles:
+        - values-hershey-park.yaml
+    path: ./theme-park-api
     repoURL: https://github.com/RyanMillerC/deploy-with-openshift-gitops.git
     targetRevision: main # Argo will default to `master`
   # These sync policy settings allow Argo to prune outdated resoruces and fix
diff --git a/hershey-park/Chart.yaml b/theme-park-api/Chart.yaml
similarity index 100%
rename from hershey-park/Chart.yaml
rename to theme-park-api/Chart.yaml
diff --git a/hershey-park/templates/deployment.yaml b/theme-park-api/templates/deployment.yaml
similarity index 100%
rename from hershey-park/templates/deployment.yaml
rename to theme-park-api/templates/deployment.yaml
diff --git a/hershey-park/templates/ingress.yaml b/theme-park-api/templates/ingress.yaml
similarity index 100%
rename from hershey-park/templates/ingress.yaml
rename to theme-park-api/templates/ingress.yaml
diff --git a/hershey-park/templates/service.yaml b/theme-park-api/templates/service.yaml
similarity index 100%
rename from hershey-park/templates/service.yaml
rename to theme-park-api/templates/service.yaml
diff --git a/hershey-park/values.yaml b/theme-park-api/values-hershey-park.yaml
similarity index 100%
rename from hershey-park/values.yaml
rename to theme-park-api/values-hershey-park.yaml
```

This commit moves *./hershey-park* to *./theme-park-api*. The changes in this
repo allow for additional values files to be specified which can be used to
deploy variations of theme-park-api for other theme parks.

## Add values files and Argo CD Apps for additional theme parks ([746a7c6])

```diff
commit 746a7c6a640099dfc0cde7094c49ebe277c57db5
Author: Ryan Miller <miller@redhat.com>
Date:   Mon Oct 10 21:26:59 2022 -0400

    Add values files and Argo CD Apps for additional theme parks

diff --git a/gitops/manifests/03-application.yaml b/gitops/manifests/03-hershey-park.yaml
similarity index 100%
rename from gitops/manifests/03-application.yaml
rename to gitops/manifests/03-hershey-park.yaml
diff --git a/gitops/manifests/04-kings-dominion.yaml b/gitops/manifests/04-kings-dominion.yaml
new file mode 100644
index 0000000..7988062
--- /dev/null
+++ b/gitops/manifests/04-kings-dominion.yaml
@@ -0,0 +1,29 @@
+apiVersion: argoproj.io/v1alpha1
+kind: Application
+metadata:
+  name: kings-dominion
+  namespace: openshift-gitops
+spec:
+  destination:
+    name: in-cluster
+    namespace: theme-park-api
+  project: theme-park-api # Argo CD AppProject
+  source:
+    directory:
+      # This is necessary if you have multiple directories in a repo and only
+      # want to deploy a single directory
+      recurse: false
+    helm:
+      valueFiles:
+        - values-kings-dominion.yaml
+    path: ./theme-park-api
+    repoURL: https://github.com/RyanMillerC/deploy-with-openshift-gitops.git
+    targetRevision: main # Argo will default to `master`
+  # These sync policy settings allow Argo to prune outdated resoruces and fix
+  # resources that might be missing.
+  syncPolicy:
+    automated:
+      prune: true
+      selfHeal: true
+    syncOptions:
+      - PruneLast=true
diff --git a/gitops/manifests/05-six-flags.yaml b/gitops/manifests/05-six-flags.yaml
new file mode 100644
index 0000000..a863cda
--- /dev/null
+++ b/gitops/manifests/05-six-flags.yaml
@@ -0,0 +1,29 @@
+apiVersion: argoproj.io/v1alpha1
+kind: Application
+metadata:
+  name: six-flags
+  namespace: openshift-gitops
+spec:
+  destination:
+    name: in-cluster
+    namespace: theme-park-api
+  project: theme-park-api # Argo CD AppProject
+  source:
+    directory:
+      # This is necessary if you have multiple directories in a repo and only
+      # want to deploy a single directory
+      recurse: false
+    helm:
+      valueFiles:
+        - values-six-flags.yaml
+    path: ./theme-park-api
+    repoURL: https://github.com/RyanMillerC/deploy-with-openshift-gitops.git
+    targetRevision: main # Argo will default to `master`
+  # These sync policy settings allow Argo to prune outdated resoruces and fix
+  # resources that might be missing.
+  syncPolicy:
+    automated:
+      prune: true
+      selfHeal: true
+    syncOptions:
+      - PruneLast=true
diff --git a/theme-park-api/values-kings-dominion.yaml b/theme-park-api/values-kings-dominion.yaml
new file mode 100644
index 0000000..1ff45e9
--- /dev/null
+++ b/theme-park-api/values-kings-dominion.yaml
@@ -0,0 +1,9 @@
+# Replicas of each application
+replicaCount: 1
+
+# Domain the application will be served from
+dnsName: kings-dominion-dev.apps.dev.taco.moe
+
+applications:
+  - name: kings-dominion-dev
+    image: quay.io/rymiller/theme-park-api:kings-dominion
diff --git a/theme-park-api/values-six-flags.yaml b/theme-park-api/values-six-flags.yaml
new file mode 100644
index 0000000..bde040f
--- /dev/null
+++ b/theme-park-api/values-six-flags.yaml
@@ -0,0 +1,9 @@
+# Replicas of each application
+replicaCount: 1
+
+# Domain the application will be served from
+dnsName: six-flags-dev.apps.dev.taco.moe
+
+applications:
+  - name: six-flags-dev
+    image: quay.io/rymiller/theme-park-api:six-flags
```

This commit adds 2 additional theme park APIs in the *theme-park-api* namespace!

I can delete and redeploy everything with:

```bash
$ oc delete -f ./gitops/manifests
namespace "theme-park-api" deleted
appproject.argoproj.io "theme-park-api" deleted
application.argoproj.io "hershey-park" deleted
application.argoproj.io "kings-dominion" deleted
application.argoproj.io "six-flags" deleted

# Wait a few moments for the namespace to delete (finalizers and all that!)

$ oc create -f ./gitops/manifests
namespace/theme-park-api created
appproject.argoproj.io/theme-park-api created
application.argoproj.io/hershey-park created
application.argoproj.io/kings-dominion created
application.argoproj.io/six-flags created
```

The above commands result in 3 applications continuously deployed from my Git
repo to my OpenShift cluster with Argo CD:

![Three applications are deployed with Argo CD](/assets/2022-10-10-Deploy-Applications-with-OpenShift-GitOps/three-applications-deployed.png)

## Continuing Education

The [Argo CD Documentation] is the official reference for the open-source Argo
CD project. The [OpenShift GitOps Documentation] is the official reference for
the OpenShift GitOps Operator.

---

**Discuss this post on GitHub
[here](https://github.com/RyanMillerC/taco.moe/discussions/5)**! Comments and
feedback welcome.

---

{% endraw %}

[Example GitOps Repo]: https://github.com/RyanMillerC/deploy-with-openshift-gitops
[746a7c6]: https://github.com/RyanMillerC/deploy-with-openshift-gitops/commit/746a7c6
[7c226e5]: https://github.com/RyanMillerC/deploy-with-openshift-gitops/commit/7c226e5
[8011d79]: https://github.com/RyanMillerC/deploy-with-openshift-gitops/commit/8011d79
[Argo CD Documentation]: https://argo-cd.readthedocs.io
[OpenShift GitOps Documentation]: https://docs.openshift.com/container-platform/4.11/cicd/gitops/understanding-openshift-gitops.html
[cdff420]: https://github.com/RyanMillerC/deploy-with-openshift-gitops/commit/cdff420
[f76e2d1]: https://github.com/RyanMillerC/deploy-with-openshift-gitops/commit/f76e2d1
[faf7545]: https://github.com/RyanMillerC/deploy-with-openshift-gitops/commit/faf7545
[Writing Helm Charts isn't hard]: https://taco.moe/writing-helm-charts-isnt-hard
