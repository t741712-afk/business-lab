# Business-Lab — Entorno híbrido empresarial en AWS (~30 máquinas)

Datacenter corporativo de laboratorio desplegable con **CloudFormation**, en **2 stacks**

(**DMZ** perímetro público + **MZ** zona interna), dentro de las restricciones del entorno

**PX** (us-east-1, sin GPU/m5, sin Marketplace, sin IAM write, IMDSv2 + EBS cifrado).

> ⚠️ **Solo para laboratorio aislado y autorizado.** Contraseñas y SGs son de lab.

## Arquitectura

```text
VPC 10.0.0.0/16  (la crea y exporta el stack DMZ; MZ la importa)

│
├─ DMZ · subred pública 10.0.0.0/24 ── 7 máquinas (Internet vía IGW)
│   bastion(.10) · loadbalancer HAProxy(.20) · nginx(.31) · wordpress(.32)
│   · apache-php(.33) · IIS Windows(.34) · monitor(.40)
│
└─ MZ · 5 subredes privadas (salida vía NAT) ── 24 máquinas
    │
    ├─ App    10.0.1.0/24 : tomcat(.11) node(.12) dotnet-win(.13)
    │                         django(.14) php-fpm(.15) docker(.16)
    │
    ├─ Datos  10.0.2.0/24 : mysql(.11) postgres(.12) mssql-win(.13)
    │                         mongo+redis(.14)
    │
    ├─ Corp   10.0.3.0/24 : DC1(.10) DC2(.11) file-win(.12) mail(.13)
    │                        intranet(.14) linux-join(.15)
    │
    ├─ Client 10.0.4.0/24 : win-client-1(.11) win-client-2(.12)
    │                        lin-client(.13)
    │
    └─ Ops    10.0.5.0/24 : dns-ntp(.11) monitor(.12) siem-elk(.13)
                             nfs(.14) jenkins(.15)
```

**Mezcla de SO:** Windows Server 2022, Ubuntu 22.04, Amazon Linux 2023 (AMIs estándar vía SSM, no Marketplace).

## Monitorización

El host `monitor` de la DMZ (`10.0.0.40`) ejecuta una plataforma dedicada de monitorización con:

* **Prometheus**
* **Blackbox Exporter**
* **Grafana**
* Docker

El monitor sondea los servicios del entorno y permite comprobar rápidamente si están **levantados o caídos**.

### Servicios monitorizados

* **HTTP:** LB, nginx, WordPress, Apache, IIS, Tomcat, Node, .NET, Django, PHP-FPM, contenedores Docker, intranet, Grafana/Prometheus de Ops, Elasticsearch, Kibana y Jenkins.
* **TCP:** SSH, MySQL, PostgreSQL, MSSQL, MongoDB, Redis, LDAP (DC1/DC2), SMB, SMTP, IMAP y NFS.
* **ICMP:** las máquinas del entorno.
* **DNS:** resolución de `corp.local` contra DC1 y dnsmasq.

`probe_success == 1` = servicio **ARRIBA**.

`probe_success == 0` = servicio **CAÍDO**.

Prometheus genera la alerta `ServicioCaido` tras 1 minuto.

### Grafana

Acceso:

```text
https://<MonitorIp>/
```

El acceso utiliza **HTTPS en el puerto 443** con certificado autofirmado. El navegador mostrará una advertencia de seguridad; acepta el certificado para continuar.

Credenciales:

```text
Usuario: admin
Password: GrafanaPassword
```

Dashboard principal:

```text
Business-Lab · Estado de servicios
```

### Prometheus

Acceso:

```text
http://<MonitorIp>:9090
```

El acceso está restringido mediante `AllowedAdminCidr`.

Prometheus se utiliza internamente como datasource de Grafana.

El puerto 443 está abierto en `DmzSg` y el monitor puede alcanzar las subredes internas mediante tráfico intra-VPC.

## Mantenimiento de Prometheus

Prometheus almacena el histórico de métricas en un volumen Docker independiente.

Grafana utiliza Prometheus como datasource, por lo que **no es necesario modificar ni eliminar Grafana** para reiniciar el histórico de monitorización.

Cuando se quiera comenzar un nuevo periodo de monitorización desde cero se puede utilizar:

```bash
sudo ./scripts/reset-prometheus-data.sh
```

El script:

1. Localiza automáticamente el contenedor `prometheus`.
2. Detecta el volumen Docker montado en `/prometheus`.
3. Detiene Prometheus.
4. Elimina únicamente el contenido del almacenamiento de métricas.
5. Arranca Prometheus de nuevo.
6. Comprueba que el contenedor vuelve a estar operativo.

El script **no elimina**:

* El volumen Docker.
* La configuración de Prometheus.
* Grafana.
* Los dashboards de Grafana.
* Los contenedores.

> ⚠️ **La limpieza del histórico es destructiva.** Las métricas anteriores no pueden recuperarse después de ejecutar el script.

El script está versionado en:

```text
scripts/reset-prometheus-data.sh
```

Se recomienda utilizarlo después de finalizar una fase de despliegue, pruebas o estabilización del laboratorio, cuando se quiera que las gráficas comiencen a registrar únicamente el periodo operativo definitivo.

## Provisioning (UserData → GitHub)

Cada instancia lleva un UserData mínimo que descarga su script real de este repositorio mediante el parámetro `ScriptBaseUrl` y lo ejecuta.

Esto evita el límite de 16 KB de UserData y mantiene los YAML pequeños.

La carpeta `scripts/` contiene tanto los scripts de provisioning de las instancias como los scripts de mantenimiento del entorno.

> **Hay que publicar la carpeta `scripts/` en GitHub antes de desplegar.**

### Publicar los scripts en el repo

```bash
cd business-lab

git init -b main

git add .

git commit -m "Business-lab: 2 stacks CFN + scripts"

git remote add origin https://github.com/t741712-afk/business-lab.git

git push -u origin main
```

URL raw utilizada por los YAML:

```text
https://raw.githubusercontent.com/t741712-afk/business-lab/main/scripts
```

## Despliegue

> Requisitos: AWS CLI configurada, KeyPair en us-east-1 (por defecto `corp-lab`) y scripts publicados en GitHub.

```bash
MIIP="$(curl -s https://checkip.amazonaws.com)/32"

# 1) DMZ (crea y exporta la red)

aws cloudformation create-stack \
  --stack-name business-lab-dmz \
  --template-body file://entorno-dmz.yaml \
  --parameters \
    ParameterKey=AllowedAdminCidr,ParameterValue="$MIIP" \
    ParameterKey=KeyName,ParameterValue=corp-lab \
    ParameterKey=WindowsAdminPassword,ParameterValue='CAMBIA_ESTO#2026' \
    ParameterKey=GrafanaPassword,ParameterValue='CAMBIA_ESTO#2026'

aws cloudformation wait stack-create-complete \
  --stack-name business-lab-dmz


# 2) MZ (importa la red del stack DMZ)

aws cloudformation create-stack \
  --stack-name business-lab-mz \
  --template-body file://entorno-mz.yaml \
  --parameters \
    ParameterKey=KeyName,ParameterValue=corp-lab \
    ParameterKey=WindowsAdminPassword,ParameterValue='CAMBIA_ESTO#2026'

aws cloudformation wait stack-create-complete \
  --stack-name business-lab-mz
```

> Si el YAML de MZ supera 51.200 bytes en `--template-body`, súbelo a S3 y utiliza `--template-url https://<bucket>.s3.amazonaws.com/entorno-mz.yaml`.

## WordPress

WordPress se provisiona automáticamente durante el bootstrap de la instancia `10.0.0.32`.

El script:

```text
scripts/web-wordpress.sh
```

realiza automáticamente:

* Instalación de nginx.
* Instalación de MariaDB.
* Instalación de PHP-FPM y extensiones necesarias.
* Creación de la base de datos `wordpress`.
* Creación del usuario de base de datos `wp`.
* Descarga e instalación de WordPress.
* Configuración de `wp-config.php`.
* Instalación de WP-CLI.
* Instalación automática de WordPress.
* Creación del usuario administrador.
* Configuración del título y URL del sitio.
* Arranque de nginx, PHP-FPM y MariaDB.

Configuración del laboratorio:

```text
URL:          http://10.0.0.32
Título:       Business Lab WordPress
Administrador: admin
Email:        admin@business-lab.local
```

La instalación automática evita que WordPress quede en la pantalla inicial de instalación y garantiza que el backend esté preparado para las comprobaciones HTTP del monitor.

## Ver IPs y acceso

Para consultar las salidas del stack DMZ:

```bash
aws cloudformation describe-stacks \
  --stack-name business-lab-dmz \
  --query 'Stacks[0].Outputs' \
  --output table
```

Entrada al entorno:

```bash
ssh -i corp-lab.pem ec2-user@<BastionIp>
```

Desde el bastion se puede continuar hacia las máquinas de la MZ.

### Active Directory

El dominio:

```text
corp.local
```

puede tardar aproximadamente **20–30 minutos** en estar completamente operativo durante un despliegue limpio.

DC1 promociona y reinicia. DC2, clientes Windows, file server y otras máquinas dependientes esperan a que AD/DNS esté disponible y realizan reintentos.

Para depuración:

Linux:

```text
/var/log/bootstrap.log
```

Windows:

```text
C:\prov.log
```

La existencia de un archivo `prov.done` durante el bootstrap no debe interpretarse por sí sola como prueba de que todos los servicios de AD ya están preparados; la disponibilidad de NTDS/LDAP puede producirse posteriormente.

## Borrado

Los stacks deben eliminarse en orden inverso:

```bash
aws cloudformation delete-stack \
  --stack-name business-lab-mz

aws cloudformation wait stack-delete-complete \
  --stack-name business-lab-mz

aws cloudformation delete-stack \
  --stack-name business-lab-dmz
```

## Normativa PX cumplida

* Región **us-east-1**.
* Tipos de instancia **t2/t3 ≤ xlarge + c5.2xlarge**.
* Sin GPU.
* Sin tipos m5.
* **Sin IAM Role**.
* Acceso mediante **KeyPair/SSH/RDP**.
* **IMDSv2 obligatorio**.
* **EBS cifrado** en todas las instancias.
* **AMIs estándar** mediante SSM Public Parameters.
* Sin Marketplace.
* Secrets parametrizados mediante `WindowsAdminPassword` y `NoEcho`.

## Notas / límites

* El entorno contiene aproximadamente **30 instancias**.
* El consumo total es de aproximadamente **~70 vCPU**, incluyendo las instancias `c5.2xlarge` utilizadas para Docker y ELK.
* **Verifica la cuota de vCPU On-Demand y el coste antes de desplegar.**
* Los "clientes Windows" utilizan **Windows Server 2022** como estación de trabajo. Windows 10/11 exigiría imágenes Marketplace, bloqueadas en PX.
* Las credenciales son únicamente para el laboratorio.

Credenciales principales:

```text
Windows:
Administrator / WindowsAdminPassword

AD:
jgarcia
mlopez
afernandez
DomainJoin (Domain Admin)

BBDD:
app / App#2026
```

> ⚠️ **Estas credenciales están destinadas exclusivamente al laboratorio. No reutilizarlas en entornos reales o expuestos a Internet.**
