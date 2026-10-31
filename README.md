# Business-Lab — Entorno híbrido empresarial vulnerable en AWS

Laboratorio de pentesting desplegable con **CloudFormation** en **2 stacks**
(**DMZ** perímetro público + **MZ** zona interna), y un stack independiente para **PentAGI**.
Toda la infraestructura cumple las restricciones de la cuenta **PX**
(us-east-1, sin GPU, sin m5, sin Marketplace, sin IAM write, IMDSv2 y EBS cifrado).

> ⚠️ **Solo para laboratorio aislado y autorizado.** Todas las contraseñas de este documento son de laboratorio.
> Varias máquinas son **vulnerables a propósito**. No las expongas a Internet más allá de la DMZ prevista ni reutilices sus credenciales fuera del lab.

Ficticia empresa de laboratorio: **Laboratories Corporation TAI** (TAI Labs), sede en Berlín.
Todo el contenido visible para el usuario de cada máquina está en **inglés** y mantiene la misma marca y paleta.

---

## Índice

1. [Arquitectura](#arquitectura)
2. [Inventario de máquinas](#inventario-de-máquinas)
3. [Escenarios vulnerables](#escenarios-vulnerables)
4. [Credenciales de laboratorio](#credenciales-de-laboratorio)
5. [Monitorización](#monitorización)
6. [PentAGI](#pentagi)
7. [Provisioning (UserData → GitHub)](#provisioning-userdata--github)
8. [Despliegue](#despliegue)
9. [Verificación y estado](#verificación-y-estado)
10. [Mantenimiento](#mantenimiento)
11. [Copias de seguridad y marcha atrás](#copias-de-seguridad-y-marcha-atrás)
12. [Borrado](#borrado)
13. [Normativa PX](#normativa-px)
14. [Notas y límites](#notas-y-límites)

---

## Arquitectura

Fuente de verdad: `entorno-dmz.yaml`, `entorno-mz.yaml` y `pentagi.yaml`. El resto de la documentación debe coincidir con estos ficheros.

```text
VPC 10.0.0.0/16  (la crea y exporta el stack DMZ; MZ la importa)

├─ DMZ · subred pública 10.0.0.0/24 ── 9 instancias (Internet vía IGW)
│   bastion(.10) · loadbalancer HAProxy(.20) · web-nginx-1-intranet(.31)
│   · web-wordpress(.32) · web-apache-1-public(.33) · web-apache-2-public(.34)
│   · web-iis(.35) · monitor(.40) · servicegateway(.75)
│
└─ MZ · 5 subredes privadas (salida vía NAT) ── 24 instancias
    │
    ├─ App    10.0.1.0/24 : app-tomcat(.11) app-node(.12) app-dotnet(.13)
    │                        app-django(.14) app-php-fpm(.15) app-docker(.16)
    │
    ├─ Datos  10.0.2.0/24 : db-mysql(.11) db-postgres(.12) db-mssql(.13)
    │                        db-mongo-redis(.14)
    │
    ├─ Corp   10.0.3.0/24 : dc1(.10) dc2(.11) fileserver(.12) mailserver(.13)
    │                        intranet(.14) linux-member(.15)
    │
    ├─ Clients 10.0.4.0/24: win-client-1(.11) win-client-2(.12) lin-client(.13)
    │
    └─ Ops    10.0.5.0/24 : ops-dns-ntp(.11) ops-monitor(.12) ops-siem-elk(.13)
                             ops-nfs-backup(.14) ops-jenkins-ci(.15)
```

**Stack PentAGI** (independiente): `pentagi.yaml` crea una VPC propia `10.100.0.0/16` con subred `10.100.0.0/24`.

**Mezcla de SO:** Windows Server 2022 (DC, IIS, SQL, file server y estaciones de trabajo), Ubuntu 22.04 (Tomcat, Node, MySQL, PostgreSQL, Jenkins, correo, DNS, WordPress, PentAGI), Amazon Linux 2023 (Apache, intranet, Django, PHP-FPM, Docker, Redis, MongoDB, NFS, bastion, HAProxy, servicegateway). AMIs estándar vía SSM, no Marketplace.

---

## Inventario de máquinas

Estado según el código de los scripts en `main`:

- **Vulnerable:** tiene fallos intencionados.
- **Parcial:** solo tiene debilidades de configuración o credenciales débiles.
- **Sin fallos intencionados:** servicio funcional sin vulnerabilidades añadidas.

### DMZ (9 instancias)

| Nombre | IP | Tipo | Script | Estado |
|---|---|---|---|---|
| bastion | 10.0.0.10 | t3.micro | `bastion.sh` | Vulnerable (información sensible) |
| loadbalancer | 10.0.0.20 | t3.small | `haproxy-lb.sh` | Vulnerable |
| web-nginx-1-intranet | 10.0.0.31 | t3.small | `web-nginx.sh` | Parcial |
| web-wordpress | 10.0.0.32 | t3.small | `web-wordpress.sh` | Vulnerable |
| web-apache-1-public | 10.0.0.33 | t3.small | `web-apache-php.sh` | Vulnerable |
| web-apache-2-public | 10.0.0.34 | t3.small | `web-apache-php.sh` | Vulnerable |
| web-iis | 10.0.0.35 | t3.medium | `web-iis.ps1` | Vulnerable |
| monitor | 10.0.0.40 | t3.medium | `monitor.sh` | Fuera de alcance del pentesting (sin fallos intencionados) |
| servicegateway | 10.0.0.75 | c5.2xlarge | (sin script) | Pendiente de documentar |

> `web-apache-1-public` y `web-apache-2-public` usan el mismo script y el mismo código. El balanceador reparte entre `.33` y `.34`.

### MZ (24 instancias)

| Zona | Nombre | IP | Tipo | Script | Estado |
|---|---|---|---|---|---|
| App | app-tomcat | 10.0.1.11 | t3.medium | `app-tomcat.sh` | Vulnerable |
| App | app-node | 10.0.1.12 | t3.small | `app-node.sh` | Parcial |
| App | app-dotnet | 10.0.1.13 | t3.medium | `app-dotnet.ps1` | Vulnerable |
| App | app-django | 10.0.1.14 | t3.small | `app-django.sh` | Parcial |
| App | app-php-fpm | 10.0.1.15 | t3.small | `app-php-fpm.sh` | Vulnerable |
| App | app-docker | 10.0.1.16 | c5.2xlarge | `app-docker.sh` | Parcial |
| Datos | db-mysql | 10.0.2.11 | t3.medium | `db-mysql.sh` | Parcial |
| Datos | db-postgres | 10.0.2.12 | t3.medium | `db-postgres.sh` | Parcial |
| Datos | db-mssql | 10.0.2.13 | t3.large | `db-mssql.ps1` | Parcial |
| Datos | db-mongo-redis | 10.0.2.14 | t3.medium | `db-mongo-redis.sh` | Vulnerable |
| Corp | dc1 | 10.0.3.10 | t3.medium | `dc1.ps1` | Vulnerable |
| Corp | dc2 | 10.0.3.11 | t3.medium | `dc2.ps1` | Sin fallos intencionados |
| Corp | fileserver | 10.0.3.12 | t3.medium | `file-smb.ps1` | Vulnerable |
| Corp | mailserver | 10.0.3.13 | t3.small | `mail-postfix.sh` | Parcial |
| Corp | intranet | 10.0.3.14 | t3.small | `intranet.sh` | Vulnerable |
| Corp | linux-member | 10.0.3.15 | t3.small | `linux-domain-join.sh` | Parcial |
| Clients | win-client-1 | 10.0.4.11 | t3.medium | `client-win.ps1` | Vulnerable |
| Clients | win-client-2 | 10.0.4.12 | t3.medium | `client-win.ps1` | Vulnerable |
| Clients | lin-client | 10.0.4.13 | t3.small | `client-linux.sh` | Parcial |
| Ops | ops-dns-ntp | 10.0.5.11 | t3.micro | `ops-dns-ntp.sh` | Vulnerable |
| Ops | ops-monitor | 10.0.5.12 | t3.medium | `ops-monitor.sh` | Parcial (credenciales por defecto, Prometheus sin autenticación) |
| Ops | ops-siem-elk | 10.0.5.13 | c5.2xlarge | `ops-elk.sh` | Parcial |
| Ops | ops-nfs-backup | 10.0.5.14 | t3.small | `ops-nfs.sh` | Vulnerable |
| Ops | ops-jenkins-ci | 10.0.5.15 | t3.medium | `ops-jenkins.sh` | Vulnerable |

> `win-client-1` y `win-client-2` usan el mismo script (`client-win.ps1`).

---

## Escenarios vulnerables

Esta sección describe **qué** hay y **dónde** está en el código. No incluye pasos de explotación.
Los scripts marcan cada fallo con un comentario `VULNERABILIDAD`.

### Aplicaciones web

| Máquina | Tipo de fallo | Ubicación |
|---|---|---|
| web-apache-1/2 (DMZ) | LFI por el parámetro `page`, subida de ficheros sin validar, `diagnostic.php` con `shell_exec`, `phpinfo()` expuesto, SELinux desactivado | `apache/index.php`, `apache/diagnostic.php`, `apache/info.php`, `scripts/web-apache-php.sh` |
| loadbalancer (DMZ) | Panel de estadísticas sin contraseña (`stats admin if TRUE`), cabeceras de origen falsificables | `scripts/haproxy-lb.sh` |
| web-wordpress (DMZ) | Administrador con contraseña débil y `WP_DEBUG_LOG` accesible desde la web | `scripts/web-wordpress.sh` |
| web-iis (DMZ) | Portal de subida sin validar que ejecuta cualquier `.aspx` | `scripts/web-iis.ps1` |
| app-tomcat (App) | Tomcat Manager con usuario de despliegue débil, accesible desde cualquier IP | `scripts/app-tomcat.sh` |
| app-php-fpm (App) | SQL injection en el buscador de pedidos (concatenación directa de `q`) | `scripts/app-php-fpm.sh` |
| app-dotnet (App) | Página de diagnóstico que ejecuta comandos del sistema a través del parámetro `cmd` | `scripts/app-dotnet.ps1` |
| intranet (Corp) | Directorio `/backup` con listado activado y fichero con configuración de BBDD | `scripts/intranet.sh` |

### Active Directory y Windows

| Máquina | Tipo de fallo | Ubicación |
|---|---|---|
| dc1 (Corp) | Carga `vulnerable-AD` (safebuffer), cuenta `DomainJoin` como Domain Admin, cuentas con AS-REP y Kerberoasting, ACL `GenericWrite` de `IT-Admins` sobre `ops-svc`, script de inicio de sesión en SYSVOL con contraseña en claro (se replica a dc2) | `scripts/dc1.ps1` |
| win-client-1/2 (Clients) | Tarea programada `TAI-Maintenance` como SYSTEM que ejecuta un script modificable por `Users` | `scripts/client-win.ps1` |
| fileserver (Corp) | Recursos SMB con ficheros de prueba que contienen credenciales en claro | `scripts/file-smb.ps1` |

### Bases de datos y servicios

| Máquina | Tipo de fallo | Ubicación |
|---|---|---|
| db-mongo-redis (Datos) | MongoDB y Redis escuchando en `0.0.0.0` sin autenticación | `scripts/db-mongo-redis.sh` |
| ops-nfs-backup (Ops) | `no_root_squash`, exportaciones `rw` para toda la VPC, permisos 777 | `scripts/ops-nfs.sh` |
| ops-dns-ntp (Ops) | BIND con transferencia de zona abierta (AXFR) de `tai-internal.local` | `scripts/ops-dns-ntp.sh` |
| ops-jenkins-ci (Ops) | Imagen vulnerable de DockerLabs | `scripts/ops-jenkins.sh` |
| db-mysql / db-postgres (Datos) | Escuchan en todas las interfaces con el usuario `app` | `scripts/db-mysql.sh`, `scripts/db-postgres.sh` |
| db-mssql (Datos) | Autenticación SQL con `sa` y puerto 1433 abierto | `scripts/db-mssql.ps1` |

### Información sensible y configuración

| Máquina | Tipo de fallo | Ubicación |
|---|---|---|
| bastion (DMZ) | Nota de traspaso en `/home/ec2-user/notes/handover-ops.txt` con credenciales de Tomcat y MySQL | `scripts/bastion.sh` |
| app-django (App) | `ALLOWED_HOSTS = ["*"]`, `/admin/` expuesto, `DEBUG` sin desactivar y superusuario `admin` con contraseña por defecto | `scripts/app-django.sh` |
| app-node (App) | `POST /sequences` sin autenticación y consola `/api/docs` expuesta | `api/server.js` |
| web-nginx-1-intranet (DMZ) | Login LDAP contra DC1 sin TLS (credenciales en claro) y mensajes de error que revelan si un usuario existe | `nginx/index.php` |
| mailserver (Corp) | Usuarios de correo con contraseña compartida, IMAP/POP3 sin TLS | `scripts/mail-postfix.sh` |
| linux-member (Corp) | Contraseña de `DomainJoin` en el script de unión, y cuenta `itsupport` con `sudo` sin contraseña para un editor | `scripts/linux-domain-join.sh` |
| db-postgres (Datos) | Superusuario `postgres` con contraseña débil y acceso sin contraseña desde la subred de clientes | `scripts/db-postgres.sh` |
| lin-client (Clients) | `labuser` con sudo y xrdp expuesto | `scripts/client-linux.sh` |
| ops-siem-elk (Ops) | `xpack.security.enabled=false` | `scripts/ops-elk.sh` |

---

## Credenciales de laboratorio

Todas son de laboratorio. Están en los scripts, así que **cualquiera con acceso al repositorio las ve**.

| Servicio | Usuario | Contraseña | Ubicación |
|---|---|---|---|
| Windows (todas) | Administrator | `BusinessLab#2026` (parámetro `WindowsAdminPassword`) | `dc1.ps1`, `dc2.ps1`, `client-win.ps1`… |
| Dominio | DomainJoin (Domain Admin) | `BusinessLab#2026` | `dc1.ps1` |
| Dominio | jgarcia, mlopez, afernandez | Se crean en el post-setup de DC1 | `dc1.ps1` |
| Dominio | tvasquez | `Spring2026!` (AS-REP Roasting) | `dc1.ps1` |
| Dominio | svc-sql | `Summer2026!` (Kerberoasting) | `dc1.ps1` |
| Dominio | ops-svc | Se crea en `dc1.ps1` | `dc1.ps1` |
| Dominio | svc-backup | `Backup2026!` (en el script de inicio de sesión de SYSVOL) | `dc1.ps1` |
| Django (superusuario) | admin | `Admin#2026` | `app-django.sh` |
| PostgreSQL (superusuario) | postgres | `postgres` | `db-postgres.sh` |
| Linux (sudo) | itsupport | `Support#2026` | `linux-domain-join.sh` |
| Tomcat Manager | deployer | `Deploy#2026` | `app-tomcat.sh` |
| MySQL / PostgreSQL | app | `App#2026` | `db-mysql.sh`, `db-postgres.sh`, `app-php-fpm.sh` |
| MSSQL | sa | `BusinessLab#2026` | `db-mssql.ps1` |
| WordPress | admin | `Insights2026` | `web-wordpress.sh` |
| WordPress BBDD | wp | `WpLab#2026` | `web-wordpress.sh` |
| Correo | jgarcia, mlopez, afernandez | `Mail#2026` | `mail-postfix.sh` |
| Cliente Linux | labuser | `Lab#2026` | `client-linux.sh` |
| Grafana (monitor DMZ) | admin | Valor del parámetro `GrafanaPassword` (por defecto en el script: `Monitor#2026`) | `entorno-dmz.yaml`, `monitor.sh` |
| Grafana (ops-monitor) | admin | `admin` (contraseña por defecto de la imagen `grafana/grafana`, sin cambiar) | `ops-monitor.sh` |
| Prometheus (ops-monitor) | — | Sin autenticación (puerto 9090) | `ops-monitor.sh` |
| Jenkins (ops-jenkins-ci) | Según la imagen DockerLabs | Ver la imagen descargada | `ops-jenkins.sh` |
| Intranet (copia de configuración) | app | `App#2026` (en `/backup/intranet-config.bak`) | `intranet.sh` |
| Bastion (nota de traspaso) | — | Contiene `deployer` y `app` | `bastion.sh` |
| MongoDB / Redis | — | Sin autenticación | `db-mongo-redis.sh` |

> Las contraseñas de `dc1.ps1` que aparecen como `__ADMINPASS__` se sustituyen por `AdminPassword` en tiempo de ejecución.

---

## Monitorización

### Monitor de la DMZ (10.0.0.40)

`monitor.sh` despliega en Docker:

* **Prometheus**
* **Blackbox Exporter** (sondas HTTP, TCP, ICMP y DNS)
* **Grafana**

Sondea los servicios del entorno. `probe_success == 1` = **ARRIBA**; `probe_success == 0` = **CAÍDO**. Prometheus genera la alerta `ServicioCaido` tras 1 minuto.

Objetivos HTTP: LB, nginx, WordPress, Apache (×2), IIS, Tomcat, Node, .NET, Django, PHP-FPM, contenedores Docker (8081-8083), intranet, Grafana y Prometheus de Ops, Elasticsearch, Kibana y Jenkins.
Objetivos TCP: SSH del bastion, MySQL, PostgreSQL, MSSQL, MongoDB, Redis (dos instancias), LDAP y SMB de DC1 y DC2, SMB del fileserver, SMTP, IMAP y NFS.
DNS: resolución de `corp.local` contra DC1.

**Grafana** (HTTPS, puerto 443, certificado autofirmado): `https://<IP-monitor>/`, dashboard **Business-Lab · Estado de servicios**.
**Prometheus** (puerto 9090, restringido por `AllowedAdminCidr`): `http://<IP-monitor>:9090`.

### Monitor de Ops (10.0.5.12)

`ops-monitor.sh` es un despliegue **mínimo e independiente**: Prometheus y Grafana en Docker, con un único job que sondea solo tres exporters de `node` (`10.0.1.11:9100`, `10.0.2.11:9100` y `10.0.5.13:9100`). No replica la lista de objetivos del monitor de la DMZ.

---

## PentAGI

`pentagi.yaml` y `pentagi_deploy.sh` despliegan **PentAGI** (plataforma de pentesting automatizado con IA) en un host Ubuntu independiente, con su propia VPC `10.100.0.0/16`. No forma parte de la red del laboratorio y no depende de los stacks DMZ/MZ.

* `pentagi_deploy.sh`: instala Docker y PentAGI, y muestra la URL de acceso (`https://<IP>:8443`).
* Acceso restringido por `AllowedAdminCidr`.

---

## Provisioning (UserData → GitHub)

Cada instancia lleva un UserData mínimo que descarga su script real de este repositorio mediante el parámetro `ScriptBaseUrl` y lo ejecuta. Así se evita el límite de 16 KB de UserData.

Las instancias ejecutan el script **una vez, al arrancar**. Un cambio en GitHub solo afecta a las instancias que se creen o reprovisionen después.

> **Los scripts deben estar publicados en GitHub antes de desplegar.**

URL raw utilizada por los YAML:

```text
https://raw.githubusercontent.com/t741712-afk/business-lab/main/scripts
```

Copias de seguridad: los ficheros `*.bk`, `*.bk2` y `*.0ld` son versiones antiguas de los scripts y no deben desplegarse. `.gitignore` excluye `*.bk`, `*.0ld` y ficheros locales de secretos, pero **no** `*.bk2`, que aparecerá como fichero sin seguir hasta que lo añadas o lo excluyas explícitamente.

---

## Despliegue

> Requisitos: AWS CLI configurada, KeyPair en us-east-1 (por defecto `corp-lab`), scripts publicados en GitHub y cuota de vCPU On-Demand suficiente.

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
    ParameterKey=AllowedAdminCidr,ParameterValue="$MIIP" \
    ParameterKey=KeyName,ParameterValue=corp-lab \
    ParameterKey=WindowsAdminPassword,ParameterValue='CAMBIA_ESTO#2026'

aws cloudformation wait stack-create-complete \
  --stack-name business-lab-mz
```

> ⚠️ **`AllowedAdminCidr` tiene por defecto `0.0.0.0/0` en ambas plantillas.** Por eso los comandos de arriba pasan tu IP `/32`. Si lanzas los stacks sin ese parámetro, SSH y RDP quedan abiertos a Internet.

> Si `entorno-mz.yaml` supera 51.200 bytes en `--template-body`, súbelo a S3 y usa `--template-url https://<bucket>.s3.amazonaws.com/entorno-mz.yaml`.

Para ver las salidas del stack DMZ:

```bash
aws cloudformation describe-stacks \
  --stack-name business-lab-dmz \
  --query 'Stacks[0].Outputs' \
  --output table
```

Entrada al entorno (solo desde `AllowedAdminCidr`):

```bash
ssh -i corp-lab.pem ec2-user@<IP-bastion>
```

Desde el bastion se accede a la MZ.

### Active Directory

El dominio `corp.local` puede tardar **20–30 minutos** en estar operativo. DC1 promociona y reinicia; DC2, los clientes Windows, el file server y el resto de máquinas dependientes reintentan hasta que AD/DNS responde.

Para depurar:

* Linux: `/var/log/bootstrap.log` y `/var/log/prov.done`.
* Windows: `C:\prov.log`, `C:\prov.done` y `C:\prov.error`.

Que exista `prov.done` no garantiza que NTDS y LDAP estén listos. Pueden levantarse después.

---

## Verificación y estado

Estado real de lo que se ha comprobado:

| Elemento | Verificado |
|---|---|
| Sintaxis de los scripts Bash modificados | Sí (`bash -n`) |
| Sintaxis de los scripts PowerShell (`dc1.ps1`, `web-iis.ps1`, `client-win.ps1`) | No (no hay `pwsh` en el equipo de trabajo) |
| Código PHP del portal de pedidos | No (no hay `php` en el equipo de trabajo) |
| Zona DNS (`named-checkzone`) | No (se valida al provisionar `ops-dns-ntp`) |
| Despliegue real en AWS | No (laboratorio no disponible durante la preparación) |

Pendientes antes de dar el laboratorio por válido:

* Desplegar y probar cada máquina vulnerable de forma aislada.
* Comprobar la sintaxis de los scripts PowerShell y PHP en un entorno con las herramientas instaladas.
* Verificar que el monitor de la DMZ sigue resolviendo `corp.local` tras cambiar el DNS de Ops a BIND.
* Documentar `servicegateway` (10.0.0.75), que está en el YAML pero no tiene script asociado.

---

## Mantenimiento

### Reinicio del histórico de Prometheus

Prometheus guarda el histórico de métricas en un volumen Docker independiente. Grafana usa Prometheus como datasource, por lo que no hace falta tocar Grafana para reiniciar el histórico.

```bash
sudo ./scripts/reset-prometheus-data.sh
```

El script:

1. Localiza el contenedor `prometheus`.
2. Detecta el volumen montado en `/prometheus`.
3. Detiene Prometheus.
4. Elimina solo el contenido del almacenamiento de métricas.
5. Arranca Prometheus de nuevo y comprueba que responde.

**No elimina** el volumen, la configuración de Prometheus, Grafana, los dashboards ni los contenedores.

> ⚠️ **La limpieza del histórico es destructiva.** Las métricas anteriores no pueden recuperarse.

Conviene usarlo al terminar una fase de despliegue, pruebas o estabilización.

---

## Copias de seguridad y marcha atrás

Cada script modificado conserva su versión anterior junto a él:

| Script actual (se despliega) | Versión anterior (no se despliega) |
|---|---|
| `scripts/app-php-fpm.sh` | `scripts/app-php-fpm.sh.bk2` |
| `scripts/app-tomcat.sh` | `scripts/app-tomcat.sh.bk2` |
| `scripts/bastion.sh` | `scripts/bastion.sh.bk2` |
| `scripts/client-win.ps1` | `scripts/client-win.ps1.bk2` |
| `scripts/dc1.ps1` | `scripts/dc1.ps1.bk2` |
| `scripts/intranet.sh` | `scripts/intranet.sh.bk2` |
| `scripts/ops-dns-ntp.sh` | `scripts/ops-dns-ntp.sh.bk2` |
| `scripts/web-iis.ps1` | `scripts/web-iis.ps1.bk2` |
| `scripts/web-wordpress.sh` | `scripts/web-wordpress.sh.bk2` |

Para volver a una versión anterior de un script, copia el `.bk2` sobre el original.

Para revertir en GitHub, usa `git revert <commit>` y haz push. No reescribas `main` con force push.

Las instancias ya desplegadas no cambian al hacer push: solo usan el código nuevo las instancias que se creen o reprovisionen después. Para devolver una máquina a su estado anterior, la opción más limpia es eliminar su stack y volver a crearlo con el código revertido.

Lo que los scripts crean fuera de la instancia (cuentas de AD, datos de MongoDB, zona DNS) no se deshace al revertir el código. Hay que eliminarlo a mano o recrear el stack.

---

## Borrado

Los stacks se eliminan en orden inverso:

```bash
aws cloudformation delete-stack \
  --stack-name business-lab-mz

aws cloudformation wait stack-delete-complete \
  --stack-name business-lab-mz

aws cloudformation delete-stack \
  --stack-name business-lab-dmz
```

Al borrar el stack, las instancias y sus datos desaparecen. Las cuentas de AD y los datos de las bases de datos no se conservan.

---

## Normativa PX

* Región **us-east-1**.
* Tipos de instancia **t2/t3 ≤ xlarge** y **c5.2xlarge**.
* Sin GPU y sin tipos m5.
* **Sin IAM Role.** Acceso por KeyPair, SSH y RDP.
* **IMDSv2 obligatorio.**
* **EBS cifrado** en todas las instancias.
* **AMIs estándar** mediante SSM Public Parameters.
* Sin Marketplace.
* Secretos parametrizados mediante `WindowsAdminPassword` con `NoEcho`.

---

## Notas y límites

* El entorno tiene **33 instancias**: 9 en la DMZ, 24 en la MZ, más el host de PentAGI.
* Hay cuatro instancias `c5.2xlarge` (`app-docker`, `ops-siem-elk`, `servicegateway` y el host de PentAGI, según su plantilla). Suman mucho consumo de vCPU: calcúlalo a partir de la tabla de inventario y verifica la cuota On-Demand y el coste antes de desplegar.
* Las estaciones Windows usan **Windows Server 2022**, porque Windows 10/11 exige imágenes Marketplace, bloqueadas en PX.
* **Visibilidad del repositorio:** las instancias leen los scripts desde GitHub con URLs `raw`. Si el repositorio es público, cualquier fallo documentado aquí es visible para cualquiera. Si el laboratorio se usa en formación, conviene mantener las soluciones en un documento privado.
* `scripts/wordpress/index.html` no lo referencia ningún script.

> ⚠️ **Las credenciales de este documento están destinadas exclusivamente al laboratorio. No reutilizarlas en entornos reales ni expuestos a Internet.**
