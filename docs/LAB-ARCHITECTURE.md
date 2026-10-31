# Laboratories Corporation TAI — Lab Architecture & Access Guide

Internal reference for the **TAI Labs** environment. Use it to find your way around the network, reach each system, and understand what runs where.

> This lab is for authorized defensive work only. Do not share access details, keys, or addresses outside the lab team, and do not change configurations without approval from the lab coordinator.

---

## 1. Network overview

| Zone | Subnet | Purpose | Reachable from Internet |
|---|---|---|---|
| VPC | `10.0.0.0/16` | Whole lab network | No |
| DMZ (public) | `10.0.0.0/24` | Public web services, load balancer, jump host, monitoring | Public web services only |
| App | `10.0.1.0/24` | Business applications and APIs | No |
| Data | `10.0.2.0/24` | Databases | No |
| Corp | `10.0.3.0/24` | Active Directory, file, mail and intranet services | No |
| Clients | `10.0.4.0/24` | Employee workstations | No |
| Ops | `10.0.5.0/24` | DNS/NTP, monitoring, SIEM, backups, CI | No |

Internal (private) zones reach the Internet through a NAT gateway. Administrative access (SSH, RDP, Grafana and Prometheus) is only allowed from the administrator address range configured at deployment.

---

## 2. How to get in

All administrative access goes through the **bastion** in the DMZ.

```bash
# 1. Connect to the bastion (use the stack output BastionIp)
ssh -i <keypair>.pem ec2-user@<BastionIp>

# 2. From the bastion, reach Linux hosts in the internal zones
ssh ec2-user@<ip>      # Amazon Linux hosts
ssh ubuntu@<ip>        # Ubuntu hosts
```

To reuse your key on the bastion without copying it there, forward your agent:

```bash
ssh -A -i <keypair>.pem ec2-user@<BastionIp>
```

**Windows hosts (RDP)** — open a tunnel through the bastion, then point your RDP client at the local port you chose:

```bash
ssh -i <keypair>.pem -L <local-port>:<windows-host-ip>:<rdp-port> ec2-user@<BastionIp>
```

Windows accounts and passwords are issued separately by the lab coordinator.

**Service Gateway** — connect directly with its own address (stack output `ServiceGateway`):

```bash
ssh -i <keypair>.pem admin@<ServiceGatewayIp>
```

**Default SSH users by operating system**

| OS family | Default user |
|---|---|
| Amazon Linux | `ec2-user` |
| Ubuntu | `ubuntu` |
| Windows | `Administrator` (RDP) |
| Service Gateway | `admin` |

---

## 3. Stack outputs

Get the current public addresses from the DMZ stack:

```bash
aws cloudformation describe-stacks \
  --stack-name business-lab-dmz \
  --query 'Stacks[0].Outputs' \
  --output table
```

| Output | Use |
|---|---|
| `BastionIp` | Entry point for SSH and RDP |
| `LoadBalancerIp` | Public web entry point |
| `WebNginx1Ip`, `WebWordpressIp`, `WebApache1Ip`, `WebApache2Ip`, `WebIisIp` | Individual public web frontends |
| `MonitorIp` | Monitoring host |
| `GrafanaUrl` | Service status dashboard (self-signed certificate) |
| `PrometheusUrl` | Prometheus (restricted to the administrator range) |
| `ServiceGateway` | Service Gateway address |

---

## 4. DMZ hosts (`10.0.0.0/24`)

| Host | IP | OS family | Role |
|---|---|---|---|
| `bastion` | 10.0.0.10 | Amazon Linux | Jump host for SSH and RDP access |
| `loadbalancer` | 10.0.0.20 | Amazon Linux | Load balancer for public web frontends |
| `web-nginx-1-intranet` | 10.0.0.31 | Ubuntu | Operations portal and reverse proxy |
| `web-wordpress` | 10.0.0.32 | Ubuntu | TAI Insights website |
| `web-apache-1-public` | 10.0.0.33 | Amazon Linux | Public web application |
| `web-apache-2-public` | 10.0.0.34 | Amazon Linux | Public web application |
| `web-iis` | 10.0.0.35 | Windows | Public web application |
| `monitor` | 10.0.0.40 | Amazon Linux | Monitoring: Prometheus, Blackbox Exporter, Grafana |
| `servicegateway` | 10.0.0.75 | See note | Service Gateway (SSH as `admin`) |

> **Service Gateway:** provisioned from a fixed machine image without an automation script in this repository. Its operating system and role details are documented by the lab coordinator. It has a dedicated public address — treat it as an internet-facing system.

---

## 5. Internal hosts

### App zone (`10.0.1.0/24`)

| Host | IP | OS family | Role |
|---|---|---|---|
| `app-tomcat` | 10.0.1.11 | Ubuntu | Java application server |
| `app-node` | 10.0.1.12 | Amazon Linux | REST API |
| `app-dotnet` | 10.0.1.13 | Windows | .NET web application |
| `app-django` | 10.0.1.14 | Ubuntu | Corporate intranet application |
| `app-php-fpm` | 10.0.1.15 | Amazon Linux | Order management portal |
| `app-docker` | 10.0.1.16 | Amazon Linux | Container host (sample services) |

### Data zone (`10.0.2.0/24`)

| Host | IP | OS family | Role |
|---|---|---|---|
| `db-mysql` | 10.0.2.11 | Ubuntu | MySQL database |
| `db-postgres` | 10.0.2.12 | Ubuntu | PostgreSQL database |
| `db-mssql` | 10.0.2.13 | Windows | Microsoft SQL Server |
| `db-mongo-redis` | 10.0.2.14 | Amazon Linux | MongoDB and Redis |

### Corp zone (`10.0.3.0/24`)

| Host | IP | OS family | Role |
|---|---|---|---|
| `dc1` | 10.0.3.10 | Windows | Domain controller, DNS (`corp.local`) |
| `dc2` | 10.0.3.11 | Windows | Domain controller (replica), DNS |
| `fileserver` | 10.0.3.12 | Windows | File shares |
| `mailserver` | 10.0.3.13 | Ubuntu | Mail (SMTP, IMAP, POP3) |
| `intranet` | 10.0.3.14 | Amazon Linux | Corporate knowledge base |
| `linux-member` | 10.0.3.15 | Ubuntu | Domain-joined Linux server |

### Clients zone (`10.0.4.0/24`)

| Host | IP | OS family | Role |
|---|---|---|---|
| `win-client-1` | 10.0.4.11 | Windows | Employee workstation (domain) |
| `win-client-2` | 10.0.4.12 | Windows | Employee workstation (domain) |
| `lin-client` | 10.0.4.13 | Ubuntu | Employee Linux desktop |

### Ops zone (`10.0.5.0/24`)

| Host | IP | OS family | Role |
|---|---|---|---|
| `ops-dns-ntp` | 10.0.5.11 | Amazon Linux | DNS resolver and NTP |
| `ops-monitor` | 10.0.5.12 | Ubuntu | Operations monitoring (Prometheus, Grafana) |
| `ops-siem-elk` | 10.0.5.13 | Ubuntu | Log management (Elasticsearch, Kibana) |
| `ops-nfs-backup` | 10.0.5.14 | Amazon Linux | Backup storage (NFS) |
| `ops-jenkins-ci` | 10.0.5.15 | Ubuntu | CI server (Jenkins) |

---

## 6. Name resolution and domain

- **Domain:** `corp.local`, served by `dc1` (10.0.3.10) and `dc2` (10.0.3.11).
- **Internal DNS:** `ops-dns-ntp` (10.0.5.11) resolves internal names and forwards `corp.local` to the domain controllers.
- **Time:** `ops-dns-ntp` (10.0.5.11) provides NTP to the lab.

Domain-joined Windows clients and servers use the domain controllers for DNS.

---

## 7. Monitoring and logs

| Tool | Location | Purpose |
|---|---|---|
| Grafana — service status | `GrafanaUrl` (monitor) | Up/down status of lab services |
| Prometheus | `PrometheusUrl` (monitor) | Metrics and `ServicioCaido` alert (service down for 1 minute) |
| Operations monitoring | `ops-monitor` (10.0.5.12) | Node metrics for key hosts |
| Log management | `ops-siem-elk` (10.0.5.13) | Kibana dashboard |

Bootstrap logs: `/var/log/bootstrap.log` and `/var/log/prov.done` on Linux; `C:\prov.log`, `C:\prov.done` and `C:\prov.error` on Windows.

---

## 8. Ground rules

1. Stay inside the lab. Do not use lab addresses or credentials for anything outside it.
2. Access is through the bastion and the Service Gateway only.
3. Keys, passwords and addresses are confidential. Do not store them in repositories or share them in chat channels.
4. Do not change service configuration, accounts or network rules without the lab coordinator's approval.
5. Report any unexpected behaviour, outage or suspicious activity to the lab coordinator immediately.
