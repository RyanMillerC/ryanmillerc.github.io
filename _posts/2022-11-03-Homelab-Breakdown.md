---
layout: post
title:  "Homelab Breakdown"
---

I run a small lab on my home network to test configurations and integration of
different software projects for my job. This post breaks down details about my
lab.

My lab is ever changing. I'll probably update this post some day.

## Compute

I have 3 physical compute machines. They're all consumer hardware, nothing
enterprise.

---

### **vpn.taco.moe** - [Raspberry Pi 3 Model B+]

#### Description

Always-on, *"set it and forget it"*, VPN server. My router is configured to port
forward from my public IP to WireGuard on this machine.

#### Specs

* OS: [Raspberry Pi OS]

#### What does it run?

* [PiVPN (WireGuard)]

---

### **bean.taco.moe** - [Intel NUC (NUC7PJYH)]

#### Description

Always-on, low-power, multi-purpose server. This machine runs any application I
need to be available on 24/7.

#### Specs

* Intel Pentium Silver J5005 4 Core (4 Thread) Processor
* 16 GB DDR4-2400 Memory *(Officially my model doesn’t support more than 8 GB
  but it actually works with more)*
* 256 GB SATA SSD (Not sure brand)

#### What does it run?

* [k3s] Kubernetes deployment (single-node) with the following applications:
    * [cert-manager] - Awesome cloud-native way to request Let's Encrypt
      certificates and keep them up to date
    * [Home Assistant] - Manage all my smart things in one place
    * [UniFi Controller] - Manage my UniFi network
    * [Gitea] - Simple local Git server
    * [DuckDNS] - Sends up a ping to update my dynamic DNS every 5 minutes
    * [Docker Registry] - Sends up a ping to update my dynamic DNS every 5
      minutes
* [Dnsmasq] - This provides DNS for lab
* [Ansible] controller - Even though I've written any Ansible playbooks so they
  can be run from anywhere, since this machine is always on, I typically run
  playbooks from this machine.

---

### **beef.taco.moe** - Custom PC build

#### Description

Beefy, dual-purpose hypervisor+gaming custom PC build. It stays powered off
unless it's being used.

#### Specs

* **Processor:** Ryzen 5950X 16 Core (32 Thread)
* **Memory:** 128 GB DDR4-3200
* **Graphics:** EVGA FTW3 RTX 3080 Ti
* **Storage:**
  * 2 TB WD Black 750 M.2 SSD (Linux)
  * 1 TB WD Blue 570 M.2 SSD (Windows)
* **Power:** EVGA 1000W Power Supply
* **OS:** Dual-boot
  * RHEL 8 (Lab mode)
  * Windows 10 (Gaming mode)

#### What does it run?

* [Red Hat Virtualization (RHV)]
    * A couple Single-Node OpenShift (SNO) instances
    * A couple Windows 10 machines
    * GitLab Server
    * RHEL 8 Test Server
    * RHEL 7 Test Server

---

## Network

### Description

My physical network consists of Ubiquity UniFi hardware managed by a local
controller. **Outside of the VPN server, nothing is exposed outside of my local
network.**

### Hardware

* UniFi USG
* 5-Port Switch
* 2x Wireless Access Points

### VLANs

* Lab
    * All three physical machines are on this VLAN. RHV VMs have a bridged NIC
      so they get real IP addresses in this VLAN also.
* LAN
    * Everything else (laptops, phones, TVs, smart home junk, etc.)

### DNS

* I run Dnsmasq to serve local DNS.
* All records are sub-domains of `taco.moe`.
    * Some examples include `git.taco.moe` and `unifi.taco.moe`.
* The Dnsmasq nameserver is only accessible from my local network.
* Externally, `taco.moe` points to AWS Route 53 (which points to Netlify which
  hosts this blog).
* To prevent changing IPs, within the UniFi controller, I set any machines with
  a DNS entry to have a permanent DHCP reservation.

---

## Challenges I've faced

### RHV

RHV is particular about how it's started/stopped. You can't pull the plug and
expect it to come up without issue the next time you boot. To mitigate
potential issues I created an Ansible playbook to start/stop RHV. The start
playbook does the following:

* Boot the RHV manager VM
* Take RHV out of global maintenance mode
* Boot VMs by group based on tags

The stop playbook does the above in reverse, gracefully shutting down VMs.

Initially I would run the playbooks against localhost from `beef.taco.moe`.
This required `beef.taco.moe` to be up though. What I have set up now uses the
wake-on-LAN feature of my PC's motherboard. The playbooks are run from the
always-on `bean.taco.moe`. The start playbook executes the same tasks above
against `beef.taco.moe` with an additional play before those tasks which sends
a wake-on-LAN signal to the PC and waits for the machine to become available.
The shutdown playbook is the same with a shutdown command at the end to power
off the PC. This gives me complete control to start/stop my enterprise lab
environment with a single command.

## Certificates

Working without valid TLS certificates is hard. Let's Encrypt is great because
they provide free TLS certificates that are universally trusted. The downside
is that they are only valid for 3 months after being issued. cert-manager on
k3s keeps the certificates I used up to date. I use a script to pull the certs
I need from k3s secrets if I need to use those TLS certificates on other
machines.

---

**Discuss this post on GitHub
[here](https://github.com/RyanMillerC/taco.moe/discussions/6)**! Comments and
feedback welcome.

---

[Ansible]: https://docs.ansible.com/ansible/latest/index.html
[Dnsmasq]: https://dnsmasq.org
[Docker Registry]: https://docs.docker.com/registry
[DuckDNS]: https://www.duckdns.org
[Gitea]: https://gittea.dev
[Home Assistant]: https://www.home-assistant.io
[Intel NUC (NUC7PJYH)]: https://ark.intel.com/content/www/us/en/ark/products/126137/intel-nuc-kit-nuc7pjyh.html
[PiVPN (WireGuard)]: https://pivpn.io
[RHEL 8]: https://developers.redhat.com/rhel8
[Raspberry Pi 3 Model B+]: https://www.raspberrypi.com/products/raspberry-pi-3-model-b-plus
[Raspberry Pi OS]: https://www.raspberrypi.com/software
[Red Hat Virtualization (RHV)]: https://access.redhat.com/products/red-hat-virtualization
[UniFi Controller]: https://docs.linuxserver.io/images/docker-unifi-controller
[cert-manager]: https://cert-manager.io
[k3s]: https://k3s.io
