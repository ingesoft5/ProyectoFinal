# Infraestructura de la Parte 1 (AWS + Bash)

Todo se crea con scripts idempotentes: correrlos de nuevo no duplica nada y deja la infraestructura en el mismo estado.

| VM | Tipo | Contenido | URL |
|---|---|---|---|
| `circleguard-tools` | t3.xlarge (16 GB) | Jenkins, SonarQube, Nexus | `http://<ip>:8080`, `:9000`, `:8081` |
| `circleguard-dev` | t3.large (8 GB) | 5 servicios núcleo + middleware + web | `http://<ip>` |
| `circleguard-stage` | t3.large (8 GB) | igual que dev | `http://<ip>` |
| `circleguard-prod` | t3.large (8 GB) | igual que dev | `http://<ip>` |

Cada ambiente tiene su propia VM, su security group y su IP elástica (aislados entre sí).

## Requisitos (una sola vez)

1. AWS CLI v2 configurado (`aws sts get-caller-identity` responde) con un usuario IAM, no la cuenta raíz.
2. `gh` autenticado con permiso de admin sobre el repo (para crear el webhook).
3. `infra/bootstrap/.state/secrets.env` con `GITHUB_TOKEN` (PAT *classic*, scope `repo`). Opcionales: `DISCORD_WEBHOOK_URL` y `WHATSAPP_RECIPIENTS` (`+57TELEFONO:APIKEY`, separados por coma).

Esa carpeta `.state/` está en `.gitignore`: ahí quedan también las IPs, la llave SSH y las contraseñas generadas.

## Uso diario: prender solo para probar

Las VMs cuestan unos **USD 0.44/h encendidas**. Se prenden para probar o demostrar y se apagan al terminar.

```bash
./infra/bootstrap/up.sh               # crea o enciende todo y lo deja configurado (~3 min si ya existe)
./infra/bootstrap/up.sh tools         # solo Jenkins/Sonar/Nexus, p. ej. para probar el pipeline (~USD 0.17/h)
./infra/bootstrap/down.sh             # apaga las 4 VMs (los datos y las IPs se conservan)
./infra/bootstrap/down.sh stage prod  # apaga solo esas
```

Apagadas solo se paga el disco y las IPs elásticas (~USD 0.90/día en total). Para borrar todo al final del curso:

```bash
./infra/bootstrap/down.sh --destroy
```

## Qué hace cada script

| Script | Qué hace |
|---|---|
| `up.sh` | Corre todo en orden: presupuesto (si hay `BUDGET_EMAIL`), nube, herramientas y los 3 ambientes |
| `bootstrap-budget.sh` | Presupuesto mensual de AWS con alertas por correo |
| `bootstrap-cloud.sh` | Key pair, security groups, VMs e IPs elásticas |
| `bootstrap-tools.sh` | Nexus, SonarQube y Jenkins (JCasC) configurados por API, y el webhook de GitHub |
| `bootstrap-env.sh <env>` | Docker, llave de despliegue de Jenkins y acceso al registro en cada ambiente |
| `remote/host-common.sh` | Corre dentro de cada VM: Docker, registro inseguro, `vm.max_map_count`, swap |
| `down.sh` | Apaga o destruye |

## Accesos

Las contraseñas están en `infra/bootstrap/.state/secrets.env`:

| Herramienta | Usuario | Variable |
|---|---|---|
| Jenkins | `jmrojas06` / `pierrecuevas` | `JENKINS_JMROJAS06_PASSWORD` / `JENKINS_PIERRECUEVAS_PASSWORD` |
| Jenkins (docente, solo lectura) | `docente` | `JENKINS_DOCENTE_PASSWORD` |
| SonarQube | `admin` | `SONAR_ADMIN_PASSWORD` |
| Nexus | `admin` | `NEXUS_ADMIN_PASSWORD` |

SSH a una VM: `ssh -i infra/bootstrap/.state/circleguard-key.pem ubuntu@<ip>`.
