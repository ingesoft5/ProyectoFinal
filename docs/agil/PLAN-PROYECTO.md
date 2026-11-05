# Plan del Proyecto Final — CircleGuard DevOps

> Equipo: **A** = `jmrojas06` (plataforma) y **B** = `pierrecuevas` (aplicación y calidad). Documento vivo: se actualiza en cada *planning*, *review* y retro.
> Backlog en GitHub: [issues](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues) con milestones *Sprint 0/1/2* y etiquetas `resp: A` / `resp: B`. Numeración: S0-01…S0-07 = #1…#7, HU-01…HU-27 = #8…#34 (HU-*n* = #(*n*+7)), HU-28 = #38 y HU-29 = #39.
> Marco: **Scrum** con 3 sprints, que son los que impone el enunciado.

## Calendario

| Sprint | Fechas | Objetivo | Cierra con |
|---|---|---|---|
| **Sprint 0** | mié 4 nov | Equipo, marco ágil, branching, backlog, nube lista, código base cargado y en verde | *Planning* del Sprint 1 |
| **Sprint 1** | jue 5 – dom 8 nov | Pipeline CI/CD de punta a punta sobre los 3 ambientes (**Parte 1**, entregables E1.1-E1.8) | **Entrega Parte 1: dom 8 nov, 23:59** + *review* y retro |
| Sustentación Sprint 1 | **lun 9 nov** | Demostrar la Parte 1 | Feedback → entra al backlog del Sprint 2 |
| **Sprint 2** | lun 9 – dom 22 nov | IaC, Kubernetes, observabilidad, patrones, seguridad, pruebas avanzadas (**Parte 2**, E2.1-E2.10) | **Entrega Parte 2: dom 22 nov, 23:59** + sustentación final |

**Regla para el domingo:** todo lo de la Parte 1 queda **en verde, desplegado y con evidencia** antes de las 23:59. El lunes solo se sustenta; no se programa.

---

## Cómo se trabaja (vale para los 3 sprints)

### Ceremonias

| Ceremonia | Cuándo | Duración | Resultado (va a `docs/agil/sprint-N.md`) |
|---|---|---|---|
| *Sprint planning* | Inicio de cada sprint | 45 min | Objetivo, historias elegidas, puntos y quién las toma |
| *Daily* | Cada día, 9:00 (chat o llamada) | 10 min | Qué hice, qué haré, qué me bloquea (se anota en un hilo) |
| *Sprint review* | Último día del sprint | 30 min | Demo de lo terminado contra los criterios de aceptación |
| Retrospectiva | Justo después de la *review* | 20 min | Qué salió bien, qué mal y 2-3 acciones concretas para el siguiente sprint |

### Definición de Terminado (DoD)
Una historia pasa a **Done** solo si:
1. Está en `main` mediante un PR **aprobado por el otro integrante**.
2. El pipeline está en verde (build, pruebas, Sonar).
3. Cumple **todos** sus criterios de aceptación.
4. Tiene **evidencia** guardada (captura o enlace a la ejecución) en `docs/evidencias/sprint-N/`.
5. La documentación que la toca está actualizada.

### Reglas de trabajo
- 1 historia = 1 issue en GitHub Projects. Cada tarea técnica es un *sub-issue* o una casilla dentro del issue.
- 1 tarea = 1 rama (`feat/…`, `fix/…`, `chore/…`, `docs/…`, `ci/…`) = 1 PR pequeño con `Closes #N`.
- Commits con Conventional Commits (`feat(auth): …`, `ci(jenkins): …`, `fix(gateway): …`).
- Nada directo a `main`.
- Los prompts de IA se guardan en `IAG_REGISTRO.md` a medida que se usan, no al final.

---

## Diagnóstico del código base (4 nov)

**Lo que hay:** monorepo Gradle (Java 21, Spring Boot 3.2.4), 8 microservicios, cliente Expo en `mobile/`, `docker-compose.dev.yml` con el middleware, migraciones Flyway, 50 pruebas.

**Lo que no hay:** Dockerfiles, Jenkinsfile, `infra/`, `deploy/`, pruebas E2E/rendimiento, Actuator, JaCoCo, Sonar, Resilience4j ni observabilidad.

### Resultado del build en limpio
> ✅ **Resuelto en #6:** 51 pruebas, 0 fallas desde un clon limpio (la de rendimiento corre aparte con `performanceTest`). Causas reales en [`sprint-0.md` §3](sprint-0.md#3-diagnóstico-del-código-base).

`gradle build --continue` en `gradle:8.14-jdk21`: **los 8 servicios compilan; 10 de 50 pruebas fallan.**

| Servicio | Prueba | Fallo | Causa probable |
|---|---|---|---|
| form | `AttachmentControllerTest` (1) | `Failed to load ApplicationContext` | Falta un bean o un mock en el `@WebMvcTest` |
| identity | `IdentityVaultControllerTest` (4) | `Failed to load ApplicationContext` | Igual (Kafka/JWT sin mockear) |
| promotion | `HealthStatusControllerTest` (2) | `expected 200 but was 403` | Los permisos del usuario de prueba no cuadran con `SecurityConfig` |
| promotion | 3 pruebas con Testcontainers | `Could not find a valid Docker environment` | **No es del código:** el agente de Jenkins necesitará el socket de Docker |

### Problemas encontrados

| # | Problema | Dónde | Arreglo |
|---|---|---|---|
| C1 | Falta `gradle-wrapper.jar` (el `.gitignore` ignora `*.jar`), así que `./gradlew` no corre en un clon limpio | `.gitignore`, `gradle/wrapper/` | `gradle wrapper --gradle-version 8.14` + regla `!gradle/wrapper/gradle-wrapper.jar` |
| C2 | Carpetas `bin/` de Eclipse versionadas (28 archivos) | `services/*/bin/` | `git rm -r` + ignorar `bin/` |
| C3 | Archivos sobrantes: `dashboard_test_output.txt`, `mobile/test-output.txt`, `scratch/`, `.agent/` | raíz | Borrar |
| C4 | Secretos en texto plano (BD, `jwt.secret`, `qr.secret`, `vault.*`) | `application.yml` de cada servicio, `docker-compose.dev.yml` | `${VAR:valor-dev}` y valores reales en `.env` no versionado |
| C5 | `localhost` escrito en todos los `application.yml` | idem | Variables de entorno de Spring (`SPRING_DATASOURCE_URL`, etc.) en el compose; no hace falta tocar código |
| C6 | Sin Actuator; `identity` y `promotion` exigen autenticación para todo | `build.gradle.kts`, `SecurityConfig` | `spring-boot-starter-actuator` + `permitAll()` en `/actuator/health/**` |
| C7 | `useGateValidation.ts` importa `API_BASE_URL`, que no existe | `mobile/hooks/useGateValidation.ts:2` | Usar `GATEWAY_BASE_URL` |
| C8 | El cliente web tiene las URLs fijas a `localhost:<puerto>` | `mobile/constants/Config.ts` | Nginx como *reverse proxy* en la imagen web y rutas relativas: una sola imagen para los 3 ambientes |
| C9 | Sin JaCoCo ni plugin de Sonar | `build.gradle.kts` raíz | Plugins `jacoco` y `org.sonarqube` |

### Riesgos externos (se resuelven en el Sprint 0)

| # | Riesgo | Acción |
|---|---|---|
| R1 | Somos 2 y el enunciado pide 3-4 | Escribirle al docente y guardar la respuesta en `sprint-0.md` |
| R2 | Al inicio GitHub respondía `403` a la protección de ramas (org Free, repo privado) | ✅ Resuelto el 4 nov: `main` protegida |
| R3 | El nombre `ProyectoFinal` no seguía la convención de los otros equipos | ✅ Renombrado a `circle-guard-finalproject-A00405392-A00405468` |
| R4 | Cuenta de nube y límites de instancias | AWS, cuenta propia; falta crear la alarma de presupuesto |

---

# SPRINT 0 — mié 4 nov

**Objetivo:** dejar listo todo lo necesario para que el Sprint 1 sea solo construir el pipeline.

| Issue | Tarea | Resp. | Terminado cuando… | Evidencia |
|---|---|---|---|---|
| S0-01 (#1) | Resolver R1-R4 (mensaje al docente, renombrar repo, cuenta de nube) | A | Respuestas anotadas | Captura del mensaje y del repo |
| S0-02 (#2) | **GitHub Project**: columnas *Backlog → Sprint backlog → In progress → Review → Done*; campos *Sprint*, *Story Points* y *Entregable*; vistas Board y Roadmap. Los issues del backlog ya están creados | A | Tablero con todos los issues, compartido con el docente | Captura |
| S0-03 (#3) | `CONTRIBUTING.md`: GitHub Flow, nombres de rama, Conventional Commits, DoD, política de revisión | A | Fusionado vía PR revisado por B | PR |
| S0-04 (#4) | `.github/pull_request_template.md` y `.github/ISSUE_TEMPLATE/{historia,bug,solicitud-cambio}.md` | B | Fusionado vía PR revisado por A | PR |
| S0-05 (#5) | Proteger `main`: PR obligatorio, 1 aprobación, *squash*, sin *force push*; el check de Jenkins se añade en HU-04 | A | Regla activa | Captura de la regla |
| S0-06 (#6) | **Código base limpio y en verde**: C1, C2, C3 y las 7 pruebas rotas | B | `./gradlew build` pasa en un clon limpio (las 3 de Testcontainers con Docker local) | Salida del build |
| S0-07 (#7) | `docs/agil/sprint-0.md`: decisiones con justificación y *planning* del Sprint 1 | A+B | Fusionado vía PR | PR |

**Decisiones del Sprint 0** (se copian a `sprint-0.md`):

| Tema | Decisión | Por qué |
|---|---|---|
| Marco | **Scrum** | El enunciado ya impone 3 iteraciones con *review*, retro y *burndown*; Scrum lo modela tal cual. |
| Branching | **GitHub Flow** | Con 2 personas GitFlow es burocracia. Los ambientes se promueven con la misma imagen, no con ramas. |
| Versionado | **semantic-release** en Jenkins | Tag `vX.Y.Z`, GitHub Release y `CHANGELOG.md` a partir de los commits. |
| Validación de commits | **commitlint** en el pipeline | Impide que entren mensajes que rompan el semver. |
| Registro | **Nexus** (repositorio Docker) | Es lo que pide E1.2. Si falta RAM: `registry:2` con autenticación. |
| Notificaciones | **Discord webhook** | Es lo más rápido de configurar. |
| Despliegue P1 | Jenkins → SSH → `docker compose pull && up -d` | Simple e idempotente; el *rollback* es redesplegar otro tag. |

---

# SPRINT 1 — jue 5 a dom 8 nov → Parte 1

**Objetivo del sprint:** *"Un commit en una rama llega a producción de forma automática, probada, versionada y con aprobación, sobre los 3 ambientes."*

### Sprint backlog

| ID | Historia | Criterios de aceptación | Entregable | Resp. | Pts |
|---|---|---|---|---|---|
| HU-01 | Como equipo quiero aprovisionar la nube con un comando para reconstruirla desde cero | `infra/bootstrap/*.sh` corridos 2 veces no cambian nada; Jenkins, Sonar y Nexus accesibles; 3 VMs de ambiente con Docker | E1.2 | A | 5 |
| HU-02 | Como plataforma quiero imágenes inmutables para desplegar lo mismo en todos los ambientes | 8 servicios + web con Dockerfile *multi-stage*, usuario no root, tag semver (nunca `latest`), publicadas en Nexus | E1.3 | B | 5 |
| HU-03 | Como operador quiero un compose por ambiente con *healthchecks* | `deploy/compose/{dev,stage,prod}`; todos los contenedores `healthy`; secretos en `.env` fuera del repo | E1.3 | B | 3 |
| HU-04 | Como desarrollador quiero CI en cada PR para no romper `main` | Multibranch + webhook; Shared Library; JaCoCo; Sonar con *quality gate* que bloquea; estado visible en el PR | E1.4 | A | 8 |
| HU-05 | Como desarrollador quiero pruebas unitarias suficientes | Cobertura de líneas ≥ 60 % en auth, identity, promotion, form y gateway, publicada en Jenkins | E1.6 | B | 8 |
| HU-06 | Como desarrollador quiero pruebas de integración entre servicios | 3 pruebas con Testcontainers en verde dentro del pipeline | E1.6 | B | 5 |
| HU-07 | Como usuario quiero que los flujos críticos funcionen en web | Playwright: login, cuestionario y validación de acceso; reporte HTML publicado | E1.6 | B | 5 |
| HU-08 | Como plataforma quiero promoción automática entre ambientes | dev automático, stage tras pasar los E2E, prod con `input`; Discord avisa los fallos | E1.5 | A | 8 |
| HU-09 | Como plataforma quiero versionado automático | Tag `vX.Y.Z` + GitHub Release + `CHANGELOG.md` generados por el pipeline | E1.5 / E1.7 | A | 3 |
| HU-10 | Como operador quiero volver a una versión anterior | Job de *rollback* ejecutado en prod con evidencia | E1.5 | A | 2 |
| HU-11 | Como equipo quiero un proceso formal de cambios | Plantilla de solicitud de cambio, política de aprobación por tipo y esquema de etiquetado | E1.7 | A+B | 2 |
| HU-12 | Como evaluador quiero poder reproducir el proyecto | README operativo, diagrama de arquitectura y del pipeline, `IAG_REGISTRO.md` | E1.8 | A+B | 3 |
| HU-13 | Como equipo quiero cerrar el sprint con evidencia | `sprint-1.md` con *review* y retro; **video de 3-5 min** del pipeline; informe PDF entregado | E1.1 / E1.8 | A+B | 2 |
| HU-28 | Como equipo queremos medir el avance de cada sprint | Burndown diario del Sprint 1 y 2 y velocidad comparada en `docs/agil/metricas/` | E1.1 / E2.9 | A | 2 |
| | | | | **Total** | **61** |

### Paso a paso (en orden de dependencias)

Cada día tiene una tarea para A y otra para B que **no se bloquean entre sí**. Al final de cada paso se toma la evidencia.

---

#### Paso 1.1 — Infraestructura en la nube con Bash (E1.2) · **A** · jueves

1. `infra/bootstrap/lib.sh`: funciones comunes (`log`, `require`, `ensure_pkg`, `ensure_docker`).
2. `infra/bootstrap/bootstrap-cloud.sh`: crea con AWS CLI (idempotente, consulta antes de crear) *key pair*, *security groups* y las 4 VMs con etiquetas `env=tools|dev|stage|prod`.
3. `infra/bootstrap/bootstrap-tools.sh`: instala Docker en `cg-tools` y levanta `infra/tools/docker-compose.yml` con:
   - Jenkins (imagen propia con `plugins.txt` + **JCasC** `jenkins.yaml`: credenciales, librería compartida, Sonar y Discord);
   - SonarQube + Postgres;
   - Nexus con repositorio Docker *hosted*.
4. `infra/bootstrap/bootstrap-env.sh <dev|stage|prod>`: Docker, usuario `deploy`, carpeta `/opt/circleguard` y la llave SSH de Jenkins.
5. `infra/bootstrap/up.sh`: un solo comando que corre todo lo anterior en orden.

| VM | RAM | Contenido |
|---|---|---|
| `cg-tools` | 16 GB | Jenkins + agente con Docker, SonarQube, Nexus |
| `cg-dev`, `cg-stage`, `cg-prod` | 8 GB c/u | 5 servicios núcleo + middleware + web |

**Terminado cuando** `up.sh` corrido dos veces seguidas termina sin cambios y las 3 UIs (Jenkins, Sonar, Nexus) abren.
**Evidencia:** salida de las 2 ejecuciones, capturas de las UIs y de la consola de la nube.

---

#### Paso 1.2 — Empaquetamiento inmutable (E1.3) · **B** · jueves

1. Arreglar C4-C8 (secretos a variables, Actuator, `permitAll` en health, `API_BASE_URL`, rutas relativas en web).
2. `services/<svc>/Dockerfile` (uno por servicio, misma plantilla):
   - etapa `build`: `gradle:8.14-jdk21` → `bootJar`;
   - etapa `runtime`: `eclipse-temurin:21-jre-alpine`, usuario `app` (no root), `HEALTHCHECK` contra `/actuator/health`.
3. `mobile/Dockerfile`: `node` → `npx expo export -p web` → `nginxinc/nginx-unprivileged` con `nginx.conf` que hace *proxy* de `/api/<svc>/` a cada servicio.
4. `deploy/compose/base.yml` (middleware + 5 núcleo + web) y `deploy/compose/{dev,stage,prod}/docker-compose.yml` con *overrides* por ambiente (puertos, recursos). Usar `depends_on: condition: service_healthy`.
5. `deploy/compose/.env.example` (sin valores reales).

**Terminado cuando** `docker compose up -d` en local deja todos los contenedores `healthy` y se puede iniciar sesión en la web con `super_admin` / `password`.
**Evidencia:** `docker compose ps`, `docker images` (tamaños), captura del login.

---

#### Paso 1.3 — Pipeline CI en Jenkins (E1.4) · **A** · viernes

1. Shared Library en `jenkins/vars/`, cargada con `libraryPath: 'jenkins/'`:
   - `changedServices()`: `git diff` contra `main` → lista de servicios tocados (cambios en la raíz = todos);
   - `gradleStage(svc, task)`, `sonarScan(svc)`, `dockerBuildPush(svc, tag)`, `deployCompose(env, tag)`, `notifyDiscord(status)`.
2. `Jenkinsfile` declarativo:
   `Checkout → Commitlint → Build → Unit tests + JaCoCo → SonarQube → Quality Gate (abortPipeline: true) → Integration tests → Package → Publish (solo main)`.
3. Proyecto **multibranch** con GitHub Branch Source + **webhook** de GitHub hacia Jenkins.
4. Agregar el check de Jenkins como **obligatorio** en la protección de `main`.

**Terminado cuando** un PR muestra el check de Jenkins, un PR con cobertura baja o un *bug* nuevo queda **bloqueado** por el *quality gate* y uno que solo toca `gateway` construye solo `gateway`.
**Evidencia:** captura del Stage View, del *quality gate* en rojo bloqueando y del check en el PR.

---

#### Paso 1.4 — Pruebas automatizadas (E1.6) · **B** · viernes y sábado

1. **Unitarias:** con el reporte de JaCoCo, ir a las clases sin cubrir de `auth`, `identity`, `promotion`, `form` y `gateway` (servicios y controladores primero) hasta ≥ 60 %. Configurar `jacocoTestCoverageVerification` con `minimum = 0.60` en esos 5 servicios para que el pipeline falle si baja.
2. **Integración** (`src/integrationTest` o etiqueta `@Tag("integration")`, con Testcontainers):
   1. `form` publica `survey.submitted` → Kafka → `promotion` lo consume y actualiza Neo4j;
   2. `auth` emite un QR firmado → `gateway` lo valida (Redis);
   3. `promotion` publica `promotion.status.changed` → Kafka → `notification` despacha.
3. **E2E con Playwright** en `tests/e2e-playwright/` (TypeScript), apuntando a `BASE_URL` del ambiente:
   1. `login.spec.ts`: inicio de sesión correcto e incorrecto;
   2. `questionnaire.spec.ts`: responder y enviar el cuestionario de salud;
   3. `gate-validation.spec.ts`: el guardia valida un QR.
4. Publicar en Jenkins los reportes JUnit, JaCoCo y Playwright HTML.

**Terminado cuando** las 3 capas corren en el pipeline y sus reportes aparecen en la ejecución.
**Evidencia:** capturas de cobertura por servicio, del reporte de Playwright y de la tendencia de pruebas.

---

#### Paso 1.5 — Entrega continua y promoción (E1.5) · **A** · sábado

Flujo en `main`:
```
CI verde → semantic-release (tag vX.Y.Z + Release) → build/push imágenes X.Y.Z
→ Deploy DEV (automático) → Smoke + E2E Playwright contra DEV
→ Deploy STAGE (automático si los E2E pasan) → Smoke contra STAGE
→ input("¿Promover vX.Y.Z a PROD?") → Deploy PROD → Smoke
post { failure → Discord · success → Discord }
```
1. `deployCompose(env, tag)`: `scp` del compose → `ssh deploy@cg-<env> "IMAGE_TAG=X.Y.Z docker compose pull && up -d --wait"`.
2. Guardar en cada VM `/opt/circleguard/RELEASES` (historial de versiones desplegadas).
3. Job `rollback` (parámetros `ENV` y `VERSION`, que lista los tags de Git) que redespliega la versión anterior.
4. `.releaserc.json` de semantic-release con los plugins `commit-analyzer`, `release-notes-generator`, `changelog`, `github` y `git`.

**Terminado cuando** un `feat:` sube la versión MINOR, llega solo a dev y a stage, espera aprobación para prod, Discord avisa y el *rollback* devuelve prod a la versión anterior.
**Evidencia:** pipeline completo con la pausa de `input`, mensajes en Discord, tag y Release en GitHub, captura del *rollback*.

---

#### Paso 1.6 — Change management y release notes (E1.7) · **A + B** · sábado

1. `docs/change-management/solicitud-de-cambio.md` (plantilla, también como issue template).
2. `docs/change-management/politica.md`:

| Tipo | Ejemplo | Aprobación | Camino |
|---|---|---|---|
| Estándar | Dependencia menor, documentación | 1 revisor | Pipeline normal |
| Normal | `feat`, `fix` | 1 revisor + `input` para prod | Pipeline normal |
| Emergencia | Caída en prod | Aprobación posterior dentro de 24 h | Rama `hotfix/*` + *rollback* si aplica |

3. Esquema de etiquetado: `vMAJOR.MINOR.PATCH` según Conventional Commits; imágenes con el mismo tag + `sha-<commit>`.
4. *Release notes* automáticas (semantic-release) enlazadas desde `docs/release-notes/`.

**Evidencia:** la página de Releases en GitHub y `CHANGELOG.md`.

---

#### Paso 1.7 — Documentación (E1.8) · **A + B** · domingo

1. `README.md` operativo: requisitos, cómo levantar todo en local, cómo reconstruir la nube (`up.sh`), cómo funciona el pipeline, URLs de los ambientes.
2. `docs/arquitectura/`: diagrama de arquitectura (servicios, Kafka, BDs) y diagrama del pipeline (Mermaid).
3. `IAG_REGISTRO.md`: nivel 3 declarado, prompts usados, qué se aceptó o se cambió de la IA y una reflexión crítica.

---

#### Paso 1.8 — Cierre del Sprint 1 · **A + B** · domingo

| Hora | Actividad |
|---|---|
| 10:00 | **Ensayo general:** un cambio real (`feat:`) recorre PR → revisión → merge → dev → stage → aprobación → prod. Capturas de cada etapa. |
| 12:00 | *Rollback* en prod y captura. |
| 14:00 | **Sprint review** (demo de cada HU contra sus criterios) y **retro** → `docs/agil/sprint-1.md` con el *burndown* del sprint. |
| 16:00 | Informe PDF: enlaces al repo y al tablero, URLs de los ambientes y evidencia por entregable (E1.1-E1.8). |
| 21:00 | **Entregar** (margen de 3 h antes del cierre). |

### Plan de contingencia
Si el sábado en la noche algo va atrasado, se recorta en este orden:
1. Ejecución selectiva por servicio (se construyen todos).
2. Nexus → `registry:2`.
3. La tercera prueba de integración.

**Nunca se recorta:** pipeline verde con Sonar bloqueante, imágenes publicadas, despliegue en los 3 ambientes con aprobación y E2E dentro del pipeline. Eso suma casi todos los puntos de la Parte 1.

### Reparto por día

| Día | A (plataforma) | B (aplicación y calidad) |
|---|---|---|
| Mié 4 | Sprint 0: S0-01, S0-02, S0-03, S0-05 | Sprint 0: S0-04, **S0-06** |
| Jue 5 | **1.1** Nube + Jenkins/Sonar/Nexus | **1.2** Config, Dockerfiles, compose |
| Vie 6 | **1.3** Jenkinsfile + Shared Library | **1.4** Cobertura + integración |
| Sáb 7 | **1.5** CD, semver, Discord, rollback | **1.4** Playwright + reportes; 1.6 |
| Dom 8 | 1.7, 1.8 | 1.7, 1.8 |

---

# Sustentación del Sprint 1 — lun 9 nov

Se ensaya el domingo 8 en la noche con el pipeline real. El guion y las preguntas de práctica están en la carpeta privada `estudio/` (fuera del repo, ver `.gitignore`). Regla: los dos deben poder explicar cualquier parte del proyecto.

---

# SPRINT 2 — lun 9 a dom 22 nov → Parte 2

**Objetivo del sprint:** *"Los 8 servicios corren en Kubernetes sobre infraestructura declarada con Terraform, observables, seguros y probados bajo carga."*

**Planning:** lunes 9 después de la sustentación. Entran primero las correcciones que pida el docente.

### Sprint backlog

| ID | Historia | Criterios de aceptación | Entregable | Resp. | Pts |
|---|---|---|---|---|---|
| HU-14 | Infraestructura declarada con Terraform | Módulos `network`, `compute`, `registry`, `storage`, `observability`; `envs/{dev,stage,prod}` por variables; *backend* S3 + DynamoDB con *lock*; `plan` limpio; diagrama | E2.1 | A | 13 |
| HU-15 | Los 8 servicios y el middleware en Kubernetes | *Namespace* por ambiente; ConfigMaps, Secrets, Ingress, HPA y sondas de Actuator | E2.2 | A | 13 |
| HU-16 | El pipeline gobierna Terraform y K8s | `terraform plan/apply` (con `input` en prod), Trivy bloqueante, `helm upgrade`, notificaciones | E2.3 | A | 8 |
| HU-17 | Patrón de resiliencia | Circuit Breaker + Retry (Resilience4j) en `auth→identity` y `dashboard→promotion`, con prueba de falla inyectada | E2.4 | B | 5 |
| HU-18 | Patrón de configuración | External Configuration + Feature Toggle desde ConfigMap, con prueba | E2.4 | B | 3 |
| HU-19 | Tercer patrón + patrones existentes | Cache-aside en `gateway` (o Outbox en `form`) con prueba; documentar los existentes con evidencia en el código | E2.4 | B | 5 |
| HU-20 | Métricas y dashboards | Micrometer + Prometheus; Grafana técnico por servicio y de negocio (tiempo de contención, promociones/min, *check-ins*) | E2.5 | B | 8 |
| HU-21 | Alertas | ≥ 3 alertas críticas en Alertmanager, probadas provocando la falla | E2.5 | B | 3 |
| HU-22 | Trazas y logs | Jaeger (OpenTelemetry) `form → Kafka → promotion → notification`; Loki para logs | E2.5 | B | 5 |
| HU-23 | Seguridad | Trivy continuo, secretos fuera del repo (Sealed/External Secrets), RBAC en K8s y Jenkins, TLS (cert-manager) | E2.6 | A | 8 |
| HU-24 | Rendimiento y seguridad dinámica | Locust (validación de acceso y cuestionarios; p95, *throughput* y error contra un objetivo declarado); ZAP *baseline* en el pipeline; informe | E2.7 | B | 5 |
| HU-25 | Rollback en K8s y registro de cambios | `helm rollback` ejecutado y evidenciado; *release notes* por versión; registro por ambiente | E2.8 | A | 2 |
| HU-26 | Documentación completa | Arquitectura, ágil (*burndown* de los 2 sprints), patrones, IaC, resultados de pruebas, costos (estimado y real), manual de operaciones, resumen ejecutivo en inglés | E2.9 | A+B | 5 |
| HU-29 | Bonos: chaos engineering y FinOps | Chaos Mesh con experimento que dispara alertas; *scale-to-zero* de dev y dashboard de costos | Bono | A+B | 5 |
| HU-27 | Presentación | 20-30 min, intro en inglés de 2-3 min, demo con falla provocada, ensayada 2 veces | E2.10 | A+B | 3 |
| | | | | **Total** | **91** |

### Paso a paso

| Paso | Fechas | A (plataforma) | B (aplicación y calidad) |
|---|---|---|---|
| 2.1 | lun 9 – mié 11 | **Terraform** (E2.1): *backend* S3 + DynamoDB; módulos; `envs/` | **Patrones** (E2.4): Resilience4j + prueba con falla; *feature toggle*; tercer patrón |
| 2.2 | jue 12 – sáb 14 | **Kubernetes** (E2.2): k3s, chart Helm común para los 8 servicios, middleware, Ingress, HPA, sondas | **Métricas** (E2.5): Actuator/Micrometer, Prometheus, dashboards de Grafana |
| 2.3 | dom 15 | **Review intermedia del sprint** (30 min): ¿vamos al ritmo del *burndown*? Ajustar el alcance si hace falta | |
| 2.4 | lun 16 – mar 17 | **Pipeline** (E2.3): Terraform y Helm en Jenkins, Trivy bloqueante | **Alertas, Jaeger y Loki** (E2.5) |
| 2.5 | mié 18 – jue 19 | **Seguridad** (E2.6): secretos, RBAC y TLS. *Rollback* en K8s (E2.8) | **Locust y ZAP** (E2.7) + informe de resultados |
| 2.6 | vie 20 – sáb 21 | Documentación (E2.9): IaC, costos, manual de operaciones | Documentación (E2.9): patrones, pruebas, resumen en inglés |
| 2.7 | dom 22 | **Review + retro final**, lecciones aprendidas, informe PDF, ensayo de la presentación, **entrega antes de las 21:00** | |
| Después | tras la sustentación | `terraform destroy` y apagar todo | |

**Bonos** (HU-29, solo si todo lo obligatorio está completo; hasta +0.10 cada uno, tope +0.25): *chaos engineering* con Chaos Mesh (reutiliza las alertas y sirve como la falla provocada de la demo) y FinOps (*scale-to-zero* de dev, *spot*, dashboard de costos).

---

## Estructura objetivo del repo

```
.
├── services/ … mobile/                 # código base (cambios mínimos)
├── Jenkinsfile   jenkins/vars/          # pipeline + Shared Library
├── infra/bootstrap/  infra/tools/       # Sprint 1: Bash + compose de herramientas
├── infra/terraform/{modules,envs/{dev,stage,prod}}   # Sprint 2
├── deploy/compose/{dev,stage,prod}/     # Sprint 1
├── deploy/helm/                         # Sprint 2
├── tests/{e2e-playwright,performance-locust,security-zap}/
├── observability/{prometheus,grafana,alerts}/
├── docs/{arquitectura,agil,patrones,operaciones,costos,release-notes,change-management,evidencias}/
├── .github/{pull_request_template.md,ISSUE_TEMPLATE/}
└── CHANGELOG.md  README.md  IAG_REGISTRO.md  CONTRIBUTING.md
```
