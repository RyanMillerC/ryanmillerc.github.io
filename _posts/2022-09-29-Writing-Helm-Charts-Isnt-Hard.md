---
layout: post
title:  "Writing Helm Charts Isn't Hard"
---

Writing Helm charts shouldn't be hard.
Most Helm tutorials have you start from a template created with `helm create chart-name`.
The starter template is complicated and contains a bunch of YAML you probably don't need.

This post shows my approach to creating Helm charts from scratch.

## Helm 101

Helm is a CLI tool that can render and apply templated Kubernetes (k8s) manifests.
The templated manifests are stored along with metadata and variables in a directory called a *Chart*.

A basic Helm chart contains:

* `Chart.yaml` - Metadata about the chart
* `templates/` - Templated Kubernetes manifests to deploy
* `values.yaml` - Variables for your chart

Helm uses your kubectl config (kubeconfig) to authenticate to a cluster.
You can install charts directly on a cluster with: `helm install <release-name> <chart-name>`.
If your working directory contains the Helm chart, you can shorthand the chart name to `.` (current directory).
For example, `helm install my-release .`.
Installed Helm charts can be listed, upgraded, and uninstalled from the Helm CLI.

Helm is namespaced.
If you don't specify a namespace to install into, Helm will use the current context from your kubeconfig.
If you want to specify a namespace, it works like kubectl: `--namespace <namespace>`.
Unless you explicitly set a namespace in a given manifest, k8s objects deployed with Helm will be deployed into the namespace the chart is installed to.

## Templating Engine

Helm uses Go templates.
If you are familiar with Jinja or Liquid templates, Go templates should feel similar.

**Anything wrapped in double brackets `{{ ... }}` is evaluated when the Helm executable is called.**

For example, you could inject the release name into a YAML manifest of a deployment with this:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-deployment
spec:
  ... # More stuff
```

When Helm renders the above file, it will look like:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-release-name-deployment
spec:
  ... # More stuff
```

You can view the rendered Helm chart without applying it to a cluster using `helm template .` (dot meaning the current directory).

## Writing a New Helm Chart

When I create a Helm chart, I more than likely have some YAML manifest(s) I've been testing on a cluster with `kubectl create -f manifests.yaml`.
If I have deployed manifests in a cluster that I want to pull out and put into a Helm chart, I'll extract the manifests as YAML with `oc get <type> <resource> -o yaml`.

(**Bonus:** Check out [kubectl-neat]. It strips out fields like *creationTimestap*, *uid*, etc. from YAML manifests. It makes exporting YAML manifests easy: `kubectl get <type> <resource> -o yaml | kubectl neat > manifest.yaml`)

For the rest of this post, I'm going to show an example Helm chart I put together, commit by commit. It’s always a good idea to start a new chart in a Git repo and commit incrementally.

## Add ConfigMap manifest ([bb02e83])

```diff
commit bb02e832e6cb951b7a1fbc3bc8689a0c2e909148
Author: Ryan Miller <miller@redhat.com>
Date:   Thu Sep 29 15:24:19 2022 -0400

    Add ConfigMap manifest

diff --git a/configmap.yaml b/configmap.yaml
new file mode 100644
index 0000000..58ee131
--- /dev/null
+++ b/configmap.yaml
@@ -0,0 +1,6 @@
+apiVersion: v1
+kind: ConfigMap
+metadata:
+  name: my-config
+data:
+  message: "Hello World!"
```

In this initial commit, I simply added a YAML manifest for a ConfigMap. This isn't even a Helm chart yet.

## Convert repo into a Helm chart ([bce3555])

```diff
commit bce35559a027bab299efeadf7d22dc7c9014d7fa
Author: Ryan Miller <miller@redhat.com>
Date:   Thu Sep 29 15:25:04 2022 -0400

    Convert repo into a Helm chart

diff --git a/Chart.yaml b/Chart.yaml
new file mode 100644
index 0000000..12f6821
--- /dev/null
+++ b/Chart.yaml
@@ -0,0 +1,5 @@
+apiVersion: v2
+name: my-chart
+description: A Helm chart for Kubernetes
+type: application
+version: 0.0.1
diff --git a/configmap.yaml b/templates/configmap.yaml
similarity index 100%
rename from configmap.yaml
rename to templates/configmap.yaml
```

This repo is now a Helm chart because I added *Chart.yaml* and moved the k8s manifest under *templates/*.
It's not a useful Helm chart though, because there isn't anything being templated.

Here's a quick breakdown of Chart.yaml: (For more details check the [Chart.yaml spec])

- *apiVersion* should always be `v2`
- *type* should probably be `application` unless you know what you're doing
- *version* is the semantic version of the chart. This should be bumped whenever a new version is released.

If I render the Helm chart, I get:

```bash
$ helm template .
---
# Source: my-chart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
data:
  message: "Hello World!"
```

## Abstract message contents into values.yaml ([e35133f])

```diff
commit e35133fe44ff1d0538e990ed9e44484f6fbfab8a
Author: Ryan Miller <miller@redhat.com>
Date:   Thu Sep 29 15:26:25 2022 -0400

    Abstract message contents into values.yaml

diff --git a/templates/configmap.yaml b/templates/configmap.yaml
index 58ee131..e7dd7b2 100644
--- a/templates/configmap.yaml
+++ b/templates/configmap.yaml
@@ -3,4 +3,4 @@ kind: ConfigMap
 metadata:
   name: my-config
 data:
-  message: "Hello World!"
+  message: "{{ .Values.message }}"
diff --git a/values.yaml b/values.yaml
new file mode 100644
index 0000000..df67acc
--- /dev/null
+++ b/values.yaml
@@ -0,0 +1 @@
+message: "Hello World!"
```

Now we're cooking with gas! This commit creates *values.yaml* and adds a variable used in the ConfigMap!

Rendering the Helm chart yields the same results as the last commit:

```bash
$ helm template .
---
# Source: my-chart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
data:
  message: "Hello World!"
```

## Prefix ConfigMap name with Helm release name ([b61f891])

```diff
commit b61f89128b89e79a7f1be0c682b424feb1095034
Author: Ryan Miller <miller@redhat.com>
Date:   Thu Sep 29 15:27:55 2022 -0400

    Prefix ConfigMap name with Helm release name

diff --git a/templates/configmap.yaml b/templates/configmap.yaml
index e7dd7b2..8f62be7 100644
--- a/templates/configmap.yaml
+++ b/templates/configmap.yaml
@@ -1,6 +1,6 @@
 apiVersion: v1
 kind: ConfigMap
 metadata:
-  name: my-config
+  name: {{ .Release.Name }}-config
 data:
   message: "{{ .Values.message }}"
```

It's also possible to use metadata about the Helm release in a template.

Rendering the chart now looks a bit different:

```bash
$ helm template --release-name my-chart .
---
# Source: my-chart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-chart-config
data:
  message: "Hello World!"
```

**NOTE:** I added `--release-name` to the template command. This is only necessary when running `helm template`. When running `helm install`, the release name is given as a required argument: `helm install <release-name> <chart-name>`.

## Add list of messages to ConfigMap instead of only 1 ([8abe94b])

```diff
commit 8abe94bd81de614abca7e75f6859fefb9e38bc92
Author: Ryan Miller <miller@redhat.com>
Date:   Thu Sep 29 15:30:58 2022 -0400

    Add list of messages to ConfigMap instead of only 1

diff --git a/templates/configmap.yaml b/templates/configmap.yaml
index 8f62be7..c30c5d3 100644
--- a/templates/configmap.yaml
+++ b/templates/configmap.yaml
@@ -3,4 +3,6 @@ kind: ConfigMap
 metadata:
   name: {{ .Release.Name }}-config
 data:
-  message: "{{ .Values.message }}"
+  {{- range .Values.messages }}
+  {{ .name }}: "{{ .message }}"
+  {{- end }}
diff --git a/values.yaml b/values.yaml
index df67acc..8e63bdf 100644
--- a/values.yaml
+++ b/values.yaml
@@ -1 +1,5 @@
-message: "Hello World!"
+messages:
+  - name: greeting
+    message: "Hello World!"
+  - name: greeting2
+    message: "Hello Everyone!"
```

In this commit, I made it possible to specify multiple key:value pairs to insert into the ConfigMap.
`range` is the for-each loop in Helm.
When you provide range with a value that contains a list, it loops through that list, item-by-item.

Any templates evaluation after the range statement and before the `end` statement, is scoped to the range.
This means `.message` is actually grabbing the value for the given range object being looped over.
If you need to access an item outside of the range object, you can prefix it with `$`.
For example, `$.Values.something` will grab the value of `something` at the root of your values.yaml file.

One other thing to note is the minus sign at the start of the template strings for range and end.
`{{- ... }}` removes the line from the output when rendered.
If the minus was not included, Helm would render an empty line on the lines containing range and end.

The rendered chart is now:

```bash
$ helm template --release-name my-chart .
---
# Source: my-chart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-chart-config
data:
  greeting: "Hello World!"
  greeting2: "Hello Everyone!"
```

## Describe variables in values.yaml ([d8d1951])

```diff
commit d8d19518575c2cc24bdb8eb321ac5f5ad59a900f
Author: Ryan Miller <miller@redhat.com>
Date:   Thu Sep 29 15:34:07 2022 -0400

    Describe variables in values.yaml

diff --git a/values.yaml b/values.yaml
index 8e63bdf..34fa28a 100644
--- a/values.yaml
+++ b/values.yaml
@@ -1,5 +1,9 @@
+# List of messages added to release-name-config ConfigMap
 messages:
+    # ConfigMap field key name
   - name: greeting
+    # ConfigMap field Value
     message: "Hello World!"
+
   - name: greeting2
     message: "Hello Everyone!"
```

It's always a good idea to describe your values so that someone else can easily understand what different values mean.

Since this change is comments only, the rendered template didn't change.

## Add boolean value for deploying ConfigMap ([27fabec])

```diff
commit 27fabec3a99ddd7b452c749b62a95e96cc4b3a95 (HEAD -> main)
Author: Ryan Miller <miller@redhat.com>
Date:   Thu Sep 29 15:35:58 2022 -0400

    Add boolean value for deploying ConfigMap

diff --git a/templates/configmap.yaml b/templates/configmap.yaml
index c30c5d3..80460de 100644
--- a/templates/configmap.yaml
+++ b/templates/configmap.yaml
@@ -1,3 +1,4 @@
+{{ if .Values.deployConfigMap }}
 apiVersion: v1
 kind: ConfigMap
 metadata:
@@ -6,3 +7,4 @@ data:
   {{- range .Values.messages }}
   {{ .name }}: "{{ .message }}"
   {{- end }}
+{{ end }}
diff --git a/values.yaml b/values.yaml
index 34fa28a..df003d5 100644
--- a/values.yaml
+++ b/values.yaml
@@ -1,3 +1,5 @@
+deployConfigMap: true
+
 # List of messages added to release-name-config ConfigMap
 messages:
     # ConfigMap field key name
```

I added a boolean value that can be toggled on and off to deploy the ConfigMap.

With it set to false, the rendered template is blank:

```bash
$ helm template --release-name my-chart .
# No output
```

With it set to true, the rendered template contains the ConfigMap:

```bash
$ helm template --release-name my-chart .
---
# Source: my-chart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-chart-config
data:
  greeting: "Hello World!"
  greeting2: "Hello Everyone!"
```

## Continuing Education

The [Helm Chart Template Guide] is a great resource for writing Helm charts.

Happy Helming!

[27fabec]: https://github.com/RyanMillerC/helm-101/commit/27fabec
[8abe94b]: https://github.com/RyanMillerC/helm-101/commit/8abe94b
[Chart.yaml spec]: https://helm.sh/docs/topics/charts/#the-chartyaml-file
[Helm Chart Template Guide]: https://helm.sh/docs/chart_template_guide/getting_started
[b61f891]: https://github.com/RyanMillerC/helm-101/commit/b61f891
[bb02e83]: https://github.com/RyanMillerC/helm-101/commit/bb02e83
[bce3555]: https://github.com/RyanMillerC/helm-101/commit/bce3555
[d8d1951]: https://github.com/RyanMillerC/helm-101/commit/d8d1951
[e35133f]: https://github.com/RyanMillerC/helm-101/commit/e35133f
[kubectl-neat]: https://github.com/itaysk/kubectl-neat
