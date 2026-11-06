# HU-02 (#9) y HU-03 (#10) · Imágenes y compose del ambiente dev en local — 2026-11-06
# Rama build/9-dockerfiles sobre main 674ebe8 (con los cambios de este PR). Docker 29.6.2

## Imágenes (8 servicios + web): multi-stage, usuario no root, HEALTHCHECK

| Imagen | Comprimida (se sube a Nexus) | En disco (descomprimida) | Base de ejecución | Usuario |
|---|---|---|---|---|
| circleguard-auth-service | 126 MB | 397 MB | eclipse-temurin:21-jre-alpine | app |
| circleguard-identity-service | 141 MB | 427 MB | eclipse-temurin:21-jre-alpine | app |
| circleguard-form-service | 138 MB | 420 MB | eclipse-temurin:21-jre-alpine | app |
| circleguard-promotion-service | 153 MB | 452 MB | eclipse-temurin:21-jre-alpine | app |
| circleguard-gateway-service | 108 MB | 359 MB | eclipse-temurin:21-jre-alpine | app |
| circleguard-dashboard-service | 123 MB | 389 MB | eclipse-temurin:21-jre-alpine | app |
| circleguard-file-service | 99 MB | 338 MB | eclipse-temurin:21-jre-alpine | app |
| circleguard-notification-service | 134 MB | 411 MB | eclipse-temurin:21-jre-alpine | app |
| circleguard-web | 22 MB | 80.1 MB | nginxinc/nginx-unprivileged:1.27-alpine | nginx |

## $ ./deploy/compose/compose.sh dev up -d --wait   (2 min 4 s desde cero)
```
SERVICE     IMAGE                                                 STATUS
auth        circleguard-auth-service:dev        Up 36 seconds (healthy)
form        circleguard-form-service:dev        Up 2 minutes (healthy)
gateway     circleguard-gateway-service:dev     Up 37 seconds (healthy)
identity    circleguard-identity-service:dev    Up 2 minutes (healthy)
kafka       apache/kafka:3.8.0                                    Up 2 minutes (healthy)
neo4j       neo4j:5.26.0-community                                Up 2 minutes (healthy)
postgres    postgres:16.4-alpine                                  Up 2 minutes (healthy)
promotion   circleguard-promotion-service:dev   Up 2 minutes (healthy)
redis       redis:7.2.5-alpine                                    Up 2 minutes (healthy)
web         circleguard-web:dev                 Up 2 minutes (healthy)
```

## Pruebas funcionales a través del cliente web (nginx -> servicios)
```
$ curl -X POST http://localhost:8090/api/auth/api/v1/auth/login -d {"username":"super_admin","password":"password"}
{"token":"<jwt omitido>","type":"Bearer","anonymousId":"013b7174-62af-4127-89b3-a06b619cdc55"}   -> HTTP 200
$ ... mismo usuario con clave incorrecta
   -> HTTP 401
$ GET /api/auth/api/v1/auth/qr/generate (con el JWT)   -> QR firmado emitido
$ POST /api/gateway/api/v1/gate/validate {"token": <QR>}
{"valid":true,"status":"GREEN","message":"Welcome to Campus"}   -> HTTP 200
$ GET /login (página de la app)
   -> HTTP 200
```

## Corrección en la revisión: rutas codificadas a través del nginx — 2026-11-06
Se probó la plantilla `mobile/nginx/default.conf.template` con `nginxinc/nginx-unprivileged:1.27-alpine` contra un servidor de eco que imprime la línea de petición que recibe el servicio. La pantalla de analíticas pide `/api/v1/analytics/department/<nombre con espacios, comas, paréntesis y tildes>`.
```
Antes (proxy_pass http://$upstream/$captura):
  UPSTREAM GOT: 'GET /api/v1/analytics/department/Faculty of Engineering, Design (Barberi de IngenierÃ\xada) HTTP/1.1'   <- línea de petición inválida (espacios sin codificar)
Después (rewrite ... break + proxy_pass http://$upstream):
  UPSTREAM GOT: 'POST /api/v1/analytics/department/Faculty%20of%20Engineering,%20Design%20(Barberi%20de%20Ingenier%C3%ADa) HTTP/1.1'
  UPSTREAM GOT: 'POST /api/v1/auth/login?x=1&y=a%20b HTTP/1.1'        <- conserva la codificación y el query string
  UPSTREAM GOT: 'POST / HTTP/1.1'                                      <- /api/auth/
```
