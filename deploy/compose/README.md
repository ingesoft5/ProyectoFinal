# Despliegue con Docker Compose (Parte 1)

Un compose por ambiente sobre una base común. Los tres ambientes usan **las mismas imágenes**; solo cambian `IMAGE_TAG` y la configuración.

| Archivo | Contenido |
|---|---|
| `base.yml` | Middleware (PostgreSQL, Neo4j, Kafka en KRaft, Redis), los 5 servicios núcleo (`auth`, `identity`, `form`, `promotion`, `gateway`) y el cliente `web`. Healthchecks y `depends_on: service_healthy` |
| `dev/`, `stage/`, `prod/` | Override por ambiente: nombre del proyecto, `CIRCLEGUARD_ENV`, nivel de log, límites de memoria y política de reinicio |
| `compose.sh` | `docker compose` con la base + el override del ambiente |
| `.env.example` | Variables necesarias. El `.env` real **nunca** se versiona |
| `postgres/init-db.sql` | Crea una base de datos por servicio |

## Uso

```bash
cp deploy/compose/.env.example deploy/compose/dev/.env   # y llenar los secretos
./deploy/compose/compose.sh dev up -d --wait              # todo queda healthy (~2 min)
./deploy/compose/compose.sh dev ps
./deploy/compose/compose.sh dev down                      # -v borra también los datos
```

El pipeline define `REGISTRY` (Nexus) e `IMAGE_TAG` (versión semántica). En local se usan imágenes construidas con:

```bash
docker build -f services/circleguard-auth-service/Dockerfile -t local/circleguard/circleguard-auth-service:dev .
docker build -f mobile/Dockerfile -t local/circleguard/circleguard-web:dev .
```

Los Dockerfiles se construyen **desde la raíz del repo**, porque el build de Gradle es un monorepo.

## Cómo se comunican

El cliente web es la única entrada pública (puerto `WEB_PORT`). Su nginx reenvía `/api/<servicio>/...` al servicio correspondiente dentro de la red de compose, así que el navegador nunca habla directo con los servicios y no hay problemas de CORS. Los servicios no publican puertos.

## Usuarios de prueba

`super_admin`, `health_user` y `staff_guard`, todos con clave `password` (migración `V2__seed_test_users.sql` de auth). LDAP es opcional: si no está configurado, auth usa estas cuentas locales.
