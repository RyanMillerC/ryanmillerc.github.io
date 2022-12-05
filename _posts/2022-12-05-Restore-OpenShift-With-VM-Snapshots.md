---
layout: post
title:  "Restore OpenShift with... VM Snapshots?"
---

I run OpenShift on virtual machines (VMs) in my lab and I frequently snapshot my clusters prior to testing cluster configuration changes.
I know what you're thinking:

* *"That's not how backing up OpenShift works!"*
* *"You're going to run into all kinds of problems with Etcd when you restore!"*
* *"Why not build a new cluster with the same install-config.yaml?"*

Under normal circumstances you should absolutely find a better solution to restore workloads than VM snapshots **(especially production!)**.
For lab use though, VM snapshots are an amazing tool to consistently reproduce environments to test changes against.

Snapshots provide a fast way to iterate through the development of cluster-wide automation instead of building out a new cluster to test changes.
In my experience, building a new cluster takes 45-60 minutes, while restoring a snapshot takes 5-10 minutes.

## My Workflow

Here's the typical workflow I use:

* Snapshot the cluster,
    1. Power down the worker nodes (shutdown button)
    2. Power down the control plane nodes (shutdown button)
    3. Snapshot all of the nodes
    4. Power on everything
* Go test whatever (It doesn't matter if I break the cluster since I have my snapshots!)
* Restore the cluster,
    1. Hard power down all nodes (Pull the plug - it doesn't matter since the machines will be restored!)
    2. Restore the snapshot on ALL nodes
    3. Power on everything

That's it!

This workflow is especially useful when combined with Single-Node OpenShift (SNO).
SNO deployments have only one node so it's easy to snapshot and restore a single VM.
For larger clusters it's more tedious to snapshot and restore multiple VMs but Ansible automation can help simplify the process.

## Considerations

### Don't Use Snapshots for Disaster Recovery (DR)

**Don't do this for DR. Ever.**
There are better, more failure resistant ways backup and restore workloads on OpenShift.

It's best to assume any cluster restored from a snapshot might not come back up.
Before I snapshot a cluster in my lab I think, "If this cluster didn't come back up, would that impact my work?"
If the answer is yes, I will back up whatever important data I have on the cluster through other means before snapping the machines.

### Etcd Corruption

**You absolutely must power off the nodes before creating snapshots, regardless if you snapshot/restore the machine's memory.**
This is important because you need all of the control plane nodes running Etcd to be in sync.
Gracefully shutting down the nodes puts Etcd in a clean state for when the nodes are resumed.
If you leave them on during the snapshot, you will run into Etcd issues.

OpenShift's [Shutting down the cluster gracefully] docs state to take an Etcd backup prior to shutting down a cluster.
I don't take Etcd backups in my lab.
Since I assume any cluster I shut down might not come back up, the work to take an Etcd backup isn't work it for me.

### Downtime

Obviously, shutting off the cluster off to snap the machines means downtime.
This shouldn't be a big deal in a lab environment.

### Node Certificates

OpenShift runs an internal certificate authority (CA) that issues certificates for every node in a cluster.
These node certificates are short lived.
When the cluster is provisioned, the initial certificates are only valid for 24 hours.
After the initial rotation, any issued node certificates are valid for 30 days.
OpenShift will automatically handle certificate rotation of node certificates shortly before they expire.

**The consideration here is, if the nodes are powered off, OpenShift can't automatically rotate the certificates.**
When the cluster boots after certificates have expired, the cluster will not function properly.

Thankfully there is a way to manually approve node certificates.
With `oc adm certificate approve <certs>`, a cluster admin can approve pending certificate signing requests (CSRs).

This one-liner will approve all pending certificates:

{% raw %}

```bash
oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs oc adm certificate approve
```

{% endraw %}

---

**Discuss this post on GitHub
[here](https://github.com/RyanMillerC/taco.moe/discussions/10)**! Comments and
feedback welcome.

---

[Shutting down the cluster gracefully]: https://docs.openshift.com/container-platform/4.11/backup_and_restore/graceful-cluster-shutdown.html

