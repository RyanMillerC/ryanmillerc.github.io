While some web-based applications can work with only an IP address, others require a vaild domain name. For local testing you might be able to get away with using your operating systems hosts file (`/etc/hosts`). If multiple machines need to access the application, it becomes an unnecessary challenge to keep a hosts file up to date across multiple systems. 

*Dnsmasq* can provide a local nameserver for your  network. It supports forward and reverse lookups using entries from `/etc/hosts`. It can be run on a dedicated host or on an existing host provided port 53 (UDP) is available. (I run Dnsmasq on a host with multiple other applications on different ports!)

## Installation

**NOTE:** The commands in this post are for RHEL but should work on CentOS Stream, Rocky Linux, and Fedora.

To install Dnsmasq, run:

```bash
$ dnf install -y dnsmasq
```

After installing, start and enable dnsmasq so it starts with the system on reboot:

```bash
$ systemctl start dnsmasq
$ systemctl enable dnsmasq
```

To make DNS lookup requests from other machines on your network, port 53 (UDP) needs to be opened in firewalld. The following firewalld command will open the DNS port for other machines to use:

```bash
$ firewall-cmd --zone=public --permanent --add-service=dns
```

At this point you should have a functioning DNS nameserver that resolves entries from `/etc/hosts`. This can tested from another machine on the network with:

```bash
$ nslookup <hostname from hosts file> <ip of DNS nameserver>
# Example: nslookup git.taco.moe 10.0.2.2
```

Any time I make changes to `/etc/hosts` I restart Dnsmasq with:

```bash
$ systemctl restart dnsmasq
```

## Configuration (Optional)

Dnsmasq can be configured in two places: `/etc/dnsmasq.conf` (global configuration) or `/etc/dnsmasq.d/` (modular configuration). On a fresh install, the global configuration is populated with values to get up and running quickly. I prefer leaving the out-of-box global configuration alone and adding my extra settings as modular configurations. Any `*.conf` files under `/etc/dnsmasq.d` are evaluated when Dnsmasq starts.

There are two additional settings I set in my Dnsmasq config:

* Upstream nameservers
* Wildcard records

I set my router to use my local nameserver instead of the nameservers provided by my ISP. By default Dnsmasq sets the upstream nameservers to the contents of `/etc/resolv.conf`. Unless disabled, NetworkManger sets values in `/etc/resolv.conf` based on information passed from DHCP. In my case this would create a loop:

```text
Server -> Router -> Local Nameserver -> Back to router
```

Instead of having Dnsmasq use the upstream nameserver that’s provided from DHCP, I manually set *server* entries in the Dnsmasq config with my upstream primary and secondary nameservers.

The second configuration I set are wildcard rewrites. Wildcard DNS entries match any sub-domain of a given domain. For example, `*.taco.moe` will match any sub-domain of `taco.moe`, like `test.taco.moe`, `api.taco.moe`, etc. Wildcard entries don’t work under `/etc/hosts`. Dnsmasq does support wildcard domains though a *server* entry the Dnsmasq configuration.

When you put both of these configurations together in `/etc/dnsmasq.d/lab.conf`, it looks like this:

```ini
# Upstream DNS servers
server=1.1.1.1
server=1.0.0.1

# Wildcard domains
address=/apps.ocp.taco.moe/10.0.2.100
address=/3scale.taco.moe/10.0.2.100
```

After creating or editing the above configuration, make sure to restart Dnsmasq with:

```bash
$ systemctl restart dnsmasq
```
