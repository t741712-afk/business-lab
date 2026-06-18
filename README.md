# Business-Lab — Entorno híbrido empresarial en AWS (~30 máquinas)

Datacenter corporativo de laboratorio desplegable con **CloudFormation**, en **2 stacks**
(**DMZ** perímetro público + **MZ** zona interna), dentro de las restricciones del entorno
**PX** (us-east-1, sin GPU/m5, sin Marketplace, sin IAM write, IMDSv2 + EBS cifrado).

> ⚠️ **Solo para laboratorio aislado y autorizado.** Contraseñas y SGs son de lab.

## Arquitectura

```
VPC 10.0.0.0/16  (la crea y exporta el stack DMZ; MZ la importa)
│
├─ DMZ  · subred pública 10.0.0.0/24  ── 7 máquinas (Internet vía IGW)
│   bastion(.10) · loadbalancer HAProxy(.20) · nginx(.31) · wordpress(.32)
│   · apache-php(.33) · IIS Windows(.34) · monitor(.40)
│
└─ MZ  · 5 subredes privadas (salida vía NAT)             ── 24 máquinas
    ├─ App   10.0.1.0/24 : tomcat(.11) node(.12) dotnet-win(.13) django(.14) php-fpm(.15) docker(.16)
    ├─ Datos 10.0.2.0/24 : mysql(.11) postgres(.12) mssql-win(.13) mongo+redis(.14)
    ├─ Corp  10.0.3.0/24 : DC1(.10) DC2(.11) file-win(.12) mail(.13) intranet(.14) linux-join(.15)
    ├─ Client 10.0.4.0/24: win-client-1(.11) win-client-2(.12) lin-client(.13)
    └─ Ops   10.0.5.0/24 : dns-ntp(.11) monitor(.12) siem-elk(.13) nfs(.14) jenkins(.15)
```

**Mezcla de SO:** Windows Server 2022, Ubuntu 22.04, Amazon Linux 2023 (AMIs estándar vía SSM, no Marketplace).

## Monitorización (host `monitor` en la DMZ, 10.0.0.40)

Máquina dedicada con **Prometheus + Blackbox Exporter + Grafana** (Docker) que sondea los
servicios de **las 31 máquinas** y muestra si están **levantados**:

- **HTTP (curl):** LB, nginx, wordpress, apache, IIS, tomcat, node, .NET, django, php-fpm,
  contenedores docker, intranet, grafana/prometheus de ops, elasticsearch, kibana, jenkins.
- **TCP (puerto):** SSH, MySQL, PostgreSQL, MSSQL, MongoDB, Redis, LDAP (DC1/DC2), SMB, SMTP, IMAP, NFS.
- **ICMP (ping):** las 30 máquinas del entorno.
- **DNS:** resolución de `corp.local` contra DC1 y dnsmasq.

`probe_success==1` = servicio ARRIBA; `==0` = CAÍDO (alerta `ServicioCaido` en Prometheus tras 1 min).

- **Grafana:** `https://<MonitorIp>/` (**HTTPS en el 443**, cert autofirmado → el navegador
  avisará, acepta y continúa). Usuario `admin` / `GrafanaPassword`. Dashboard *Business-Lab · Estado de servicios*.
- **Prometheus:** `http://<MonitorIp>:9090` (solo desde `AllowedAdminCidr`; uso interno como datasource).
- El 443 está abierto en `DmzSg`; el monitor alcanza todas las subredes por tráfico intra-VPC.

## Provisioning (UserData → GitHub)

Cada instancia lleva un UserData mínimo que descarga su script real de este repo
(parámetro `ScriptBaseUrl`) y lo ejecuta. Esto evita el límite de 16 KB de UserData
y mantiene los YAML pequeños. **Hay que publicar la carpeta `scripts/` en GitHub antes de desplegar.**

### Publicar los scripts en el repo

```bash
cd business-lab
git init -b main
git add .
git commit -m "Business-lab: 2 stacks CFN + scripts de provisioning"
git remote add origin https://github.com/t741712-afk/business-lab.git
git push -u origin main
```
URL raw que usan los YAML: `https://raw.githubusercontent.com/t741712-afk/business-lab/main/scripts`

## Despliegue

> Requisitos: AWS CLI configurada, KeyPair en us-east-1 (default `corp-lab`), scripts ya en GitHub.

```bash
MIIP="$(curl -s https://checkip.amazonaws.com)/32"

# 1) DMZ (crea y exporta la red)
aws cloudformation create-stack --stack-name business-lab-dmz \
  --template-body file://entorno-dmz.yaml \
  --parameters \
    ParameterKey=AllowedAdminCidr,ParameterValue="$MIIP" \
    ParameterKey=KeyName,ParameterValue=corp-lab \
    ParameterKey=WindowsAdminPassword,ParameterValue='CAMBIA_ESTO#2026' \
    ParameterKey=GrafanaPassword,ParameterValue='CAMBIA_ESTO#2026'
aws cloudformation wait stack-create-complete --stack-name business-lab-dmz

# 2) MZ (importa la red del stack DMZ)
aws cloudformation create-stack --stack-name business-lab-mz \
  --template-body file://entorno-mz.yaml \
  --parameters \
    ParameterKey=KeyName,ParameterValue=corp-lab \
    ParameterKey=WindowsAdminPassword,ParameterValue='CAMBIA_ESTO#2026'
aws cloudformation wait stack-create-complete --stack-name business-lab-mz
```

> Si el YAML de MZ supera 51.200 bytes en `--template-body`, súbelo a S3 y usa
> `--template-url https://<bucket>.s3.amazonaws.com/entorno-mz.yaml`.

## Ver IPs y acceso

```bash
aws cloudformation describe-stacks --stack-name business-lab-dmz --query 'Stacks[0].Outputs' --output table
ssh -i corp-lab.pem ec2-user@<BastionIp>     # entrada; desde aquí salta a la MZ
```
El AD (`corp.local`) tarda ~20-30 min en estar listo (DC1 promociona + reinicia;
DC2/clientes/file esperan y se unen con reintentos). Mira `/var/log/bootstrap.log`
(Linux) o `C:\prov.log` (Windows) para depurar.

## Borrado (orden inverso)

```bash
aws cloudformation delete-stack --stack-name business-lab-mz
aws cloudformation wait stack-delete-complete --stack-name business-lab-mz
aws cloudformation delete-stack --stack-name business-lab-dmz
```

## Normativa PX cumplida

- Región **us-east-1**; tipos **t2/t3 ≤ xlarge + c5.2xlarge** (sin GPU/m5).
- **Sin IAM Role** → acceso por **KeyPair/SSH/RDP** (no SSM con rol).
- **IMDSv2** obligatorio + **EBS cifrado** en todas las instancias.
- **AMIs estándar** vía SSM Public Parameters (no Marketplace).
- Secrets parametrizados (`WindowsAdminPassword`, NoEcho).

## Notas / límites

- ~30 instancias ≈ **~70 vCPU** (2× c5.2xlarge para Docker y ELK). **Verifica la cuota de
  vCPU On-Demand** y el coste antes de desplegar.
- Los "clientes Windows" usan **Windows Server 2022** como estación (Win10/11 exigiría
  Marketplace, bloqueado en PX).
- Credenciales de lab: Windows `Administrator / WindowsAdminPassword`; AD usuarios
  `jgarcia/mlopez/afernandez` y `DomainJoin` (Domain Admin); BBDD `app / App#2026`.
```
