# Sprint 0 — miércoles 4 de noviembre de 2026

| | |
|---|---|
| **Objetivo** | Dejar listo el equipo, el marco de trabajo, el backlog, la nube y el código base para que el Sprint 1 sea solo construir el pipeline. |
| **Equipo** | `jmrojas06` (A, plataforma) · `pierrecuevas` (B, aplicación y calidad) |
| **Tablero** | [GitHub Projects](https://github.com/orgs/ingesoft5/projects/8) |
| **Backlog** | [Issues](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues) · milestones [Sprint 0](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/milestone/1), [Sprint 1](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/milestone/2), [Sprint 2](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/milestone/3) |
| **Plan completo** | [`PLAN-PROYECTO.md`](PLAN-PROYECTO.md) |

## 1. Decisiones

| Tema | Decisión | Justificación |
|---|---|---|
| Marco ágil | **Scrum** | El enunciado define 3 iteraciones con *planning*, *review*, retro y *burndown*; Scrum las modela directamente. Kanban obligaría a justificar iteraciones igual. |
| Duración de sprints | Sprint 0: 1 día · Sprint 1: 4 días · Sprint 2: 2 semanas | Ajustados a las fechas de entrega (8 y 22 de noviembre). |
| Herramienta | **GitHub Projects** | Vive junto al código: los PR cierran issues (`Closes #N`) y dan trazabilidad individual de commits, PR y revisiones. |
| Branching | **GitHub Flow** (ver [`CONTRIBUTING.md`](../../CONTRIBUTING.md)) | 2 integrantes y sprints cortos: una sola rama de larga vida (`main`). Los ambientes se promueven con la misma imagen, no con ramas. |
| Commits | **Conventional Commits** validados con **commitlint** | Alimentan el versionado semántico y las *release notes* automáticas. |
| Versionado | **semantic-release** en Jenkins sobre `main` | Genera tag `vX.Y.Z`, GitHub Release y `CHANGELOG.md` sin intervención manual. |
| CI/CD | **Jenkins** multibranch + Shared Library | Lo pide el enunciado (E1.4). |
| Análisis estático | **SonarQube** con *quality gate* bloqueante | E1.4. |
| Registro de artefactos | **Nexus** (repositorio Docker *hosted*) | E1.2. Alternativa si falta RAM: `registry:2` con autenticación. |
| Notificaciones | **Discord** (webhook) | La integración más rápida con Jenkins. |
| Nube | **AWS (cuenta propia)**, EC2: `cg-tools` (16 GB) + `cg-dev`, `cg-stage`, `cg-prod` (8 GB c/u) | Ambientes aislados en VMs separadas. Se apagan cuando no se usan para controlar costos. |
| Despliegue P1 | Jenkins → SSH → `docker compose pull && up -d` | Idempotente; el *rollback* es redesplegar una versión anterior. |

### Definición de Terminado
Ver [`CONTRIBUTING.md` §5](../../CONTRIBUTING.md#5-definición-de-terminado-dod).

## 2. Riesgos y estado

| # | Riesgo | Acción | Estado |
|---|---|---|---|
| R1 | Equipo de 2 (`A00405392`, `A00405468`); el enunciado pide 3-4 | Consulta al docente | ⏳ Por enviar y esperar respuesta |
| R2 | Al inicio GitHub respondía `403` a la protección de ramas (org en plan Free, repo privado) | Se reintentó el 4 nov y la API ya la acepta | ✅ Resuelto: `main` protegida ([evidencia](../evidencias/sprint-0/proteccion-main.json)) |
| R3 | Nombre del repo fuera de la convención | Renombrado a `circle-guard-finalproject-A00405392-A00405468` | ✅ Resuelto |
| R4 | Cuenta de nube y límites | **AWS, cuenta propia** del equipo. Alarma de presupuesto en AWS Budgets (USD 50/mes, aviso al 80 %) | ✅ Cuenta definida · ⏳ alarma por crear en la consola |

### Protección de `main` aplicada

| Regla | Valor |
|---|---|
| PR obligatorio con aprobaciones | 1, descartadas si llegan commits nuevos; debe aprobar alguien distinto a quien hizo el último *push* |
| Aplica también a administradores | Sí |
| Conversaciones resueltas antes de fusionar | Sí |
| Historial lineal | Sí |
| *Force push* y borrado | Prohibidos |
| Métodos de fusión del repo | Solo *squash*; ramas borradas al fusionar ([evidencia](../evidencias/sprint-0/opciones-merge.json)) |
| Check obligatorio de Jenkins | Se agrega en [#11](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues/11) (HU-04) cuando exista el pipeline |

## 3. Diagnóstico del código base

Build inicial (`gradle build --continue`, Gradle 8.14, JDK 21): **los 8 servicios compilaban, 10 de 50 pruebas fallaban** y faltaba `gradle-wrapper.jar`. Detalle en [`PLAN-PROYECTO.md`](PLAN-PROYECTO.md#diagnóstico-del-código-base-4-nov).

**Resuelto en [#6](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues/6):** `./gradlew build` desde un clon limpio pasa con **52 pruebas, 0 fallas** ([evidencia](../evidencias/sprint-0/build-verde.txt)).

| Fallo | Causa real | Arreglo |
|---|---|---|
| form `AttachmentControllerTest` | `@SpringBootTest` completo intentaba conectarse a Postgres y Kafka | `@WebMvcTest` con `StorageService` simulado, como las demás pruebas del controlador |
| identity `IdentityVaultControllerTest` (4) | El `application.yml` de test reemplaza al de main y no define `jwt.secret`; el filtro JWT recibía el texto `${jwt.secret}` (13 bytes) | Clave JWT propia en el `application.yml` de test |
| promotion `HealthStatusControllerTest` (2) | El controlador exige `hasRole('HEALTH_CENTER')` y el JWT de auth emite `ROLE_HEALTH_CENTER`; la prueba simulaba la *authority* sin prefijo. **El código estaba bien; la prueba no** | `@WithMockUser(roles = ...)` |
| promotion, 3 con Testcontainers | (1) Testcontainers 1.19.3 usa la API 1.32 de Docker, que Docker Engine 29 rechaza; (2) dependían de Postgres y Redis corriendo en `localhost` | Testcontainers 1.21.4 + `api.version=1.44`; perfil `test` con H2 y contenedor Redis |

Limpieza (C1-C3): `gradle-wrapper.jar` versionado con `gradlew` en LF (`.gitattributes`), sin carpetas `bin/` de Eclipse ni archivos sobrantes (`scratch/`, `.agent/`, salidas de pruebas).

> **Para el agente de Jenkins (#11):** necesita el socket de Docker montado para las pruebas de Testcontainers. Con el `api.version` fijado funciona con Docker Engine 25 o superior.

## 4. Sprint backlog del Sprint 0

| Issue | Tarea | Resp. | Pts | Estado |
|---|---|---|---|---|
| [#1](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues/1) | Resolver riesgos R1-R4 | A | 1 | En revisión (R1 y alarma de AWS pendientes) |
| [#2](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues/2) | Tablero en GitHub Projects con el backlog | A | 2 | Hecho |
| [#3](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues/3) | `CONTRIBUTING.md` | A | 1 | Hecho (PR #35) |
| [#4](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues/4) | Plantillas de PR e issues | B | 1 | En revisión |
| [#5](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues/5) | Proteger `main` | A | 1 | Hecho |
| [#6](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues/6) | Código base limpio y en verde | B | 3 | En revisión |
| [#7](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues/7) | Este documento y *planning* del Sprint 1 | A+B | 1 | Hecho (PR #36) |

## 5. Planning del Sprint 1 (jue 5 – dom 8 nov)

**Objetivo:** *"Un commit en una rama llega a producción de forma automática, probada, versionada y con aprobación, sobre los 3 ambientes."*

**Capacidad:** 2 personas × 4 días. **Comprometido:** 59 puntos (A: 26 propios, B: 26 propios, 7 compartidos).

| Issue | Historia | Entregable | Resp. | Pts |
|---|---|---|---|---|
| [#8](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues/8) | HU-01 Nube con Bash idempotente | E1.2 | A | 5 |
| [#9](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues/9) | HU-02 Imágenes Docker inmutables | E1.3 | B | 5 |
| [#10](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues/10) | HU-03 Compose por ambiente | E1.3 | B | 3 |
| [#11](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues/11) | HU-04 CI en Jenkins | E1.4 | A | 8 |
| [#12](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues/12) | HU-05 Cobertura ≥ 60 % | E1.6 | B | 8 |
| [#13](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues/13) | HU-06 3 pruebas de integración | E1.6 | B | 5 |
| [#14](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues/14) | HU-07 E2E con Playwright | E1.6 | B | 5 |
| [#15](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues/15) | HU-08 Promoción entre ambientes | E1.5 | A | 8 |
| [#16](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues/16) | HU-09 Semver y release notes | E1.5 | A | 3 |
| [#17](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues/17) | HU-10 Rollback | E1.5 | A | 2 |
| [#18](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues/18) | HU-11 Change management | E1.7 | A+B | 2 |
| [#19](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues/19) | HU-12 Documentación e IAG | E1.8 | A+B | 3 |
| [#20](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues/20) | HU-13 Cierre del Sprint 1 | E1.1 | A+B | 2 |

**Orden de trabajo:**

| Día | A (`jmrojas06`) | B (`pierrecuevas`) |
|---|---|---|
| Jue 5 | #8 Nube + Jenkins/Sonar/Nexus | #9, #10 Configuración, Dockerfiles, compose |
| Vie 6 | #11 Jenkinsfile + Shared Library | #12, #13 Cobertura e integración |
| Sáb 7 | #15, #16, #17 CD, semver, rollback | #14 Playwright; #18 |
| Dom 8 | #19, #20 Ensayo, evidencias, informe | #19, #20 Ensayo, evidencias, informe |

**Ceremonias:** *daily* a las 9:00 · *review* y retro el domingo 8 a las 14:00 · entrega a las 21:00.

## 6. Sprint review y retrospectiva del Sprint 0

> Borrador con los hechos del día. Cada integrante completa sus puntos antes de fusionar.

### Review (contra el objetivo del sprint)

| Resultado | Evidencia |
|---|---|
| Backlog de 36 issues con criterios de aceptación, en 3 milestones | [Issues](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/issues) |
| Tablero con Status, Sprint, Story Points y Entregable | [Project #8](https://github.com/orgs/ingesoft5/projects/8) |
| Estrategia de ramas y DoD documentadas | PR #35 (`CONTRIBUTING.md`) |
| `main` protegida, solo *squash* | PR #37 + `docs/evidencias/sprint-0/` |
| Repo renombrado según la convención | Riesgo R3 |
| Primeros PR revisados y fusionados por el otro integrante | PR #35, #36, #37 |
| Código base en verde: 52 pruebas, 0 fallas desde un clon limpio | #6 + [`build-verde.txt`](../evidencias/sprint-0/build-verde.txt) (en revisión) |
| Plantillas de PR e issues (historia, bug, solicitud de cambio) | #4, `.github/` (en revisión) |

### Retrospectiva

| Salió bien | Por mejorar | Acción para el Sprint 1 |
|---|---|---|
| El backlog quedó completo y repartido 50/50 desde el primer día | El PR #36 se fusionó antes del último *push* del autor y un commit quedó por fuera (se recuperó en #37) | Abrir como **draft** hasta terminar; pasar a *Ready for review* solo cuando ya no haya más *push* |
| La protección de `main` quedó activa antes de empezar a programar | Las aprobaciones de #35-#37 no dejaron comentarios | Cada revisión deja al menos un comentario concreto (pregunta, sugerencia o verificación hecha) |
| Se revisó la rúbrica completa y se agregaron los criterios que faltaban a los issues (video, burndown, TLS válido, etc.) | La conexión inestable cortó varios comandos contra GitHub | Scripts con reintentos; evidencias guardadas el mismo día |
| _(pierrecuevas)_ | _(pierrecuevas)_ | _(pierrecuevas)_ |
