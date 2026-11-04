# Registro de uso de IA generativa (IAG)

| | |
|---|---|
| **Nivel declarado** | **Nivel 3 — Colaboración con IAG** (política del curso) |
| **Herramienta** | Claude Code (asistente de programación en la terminal) |
| **Regla del equipo** | Cada uso se registra en el mismo PR donde entra su resultado ([`CONTRIBUTING.md` §6](CONTRIBUTING.md#6-uso-de-ia-generativa)). Quien abre el PR revisa, ajusta y debe poder explicar todo lo generado. Ningún commit lleva a la IA como autor o coautor. |

Formato de cada entrada: fecha, integrante, contenido propio entregado, prompt, qué produjo la IA, qué se verificó o cambió.

---

## Sprint 0

### 2026-11-04 · `jmrojas06` · Diagnóstico y plan del proyecto

- **Contenido propio entregado:** el enunciado del proyecto (`Proyecto_Final_CircleGuard.tex`/`.pdf`), el repositorio base y los requisitos de metodología pegados del enunciado.
- **Prompts (textuales):**
  1. *"Quiero que revises el repo, y me digas que hay que hacer, planees todo. Para mi compañero y yo."* (+ sección de requisitos del enunciado)
  2. *"Pero entonces ya esta dividido en sprints? hay que hacerlo bien. Hay que tener todo para el domingo, y lo ideal seria hacerlo entonces paso a paso con lo que nos piden, hay que sustentar hasta el sprint 1 el lunes. Y luego el sprint 2 es el resto del proyecto."*
- **Qué produjo:** diagnóstico del repositorio (archivos faltantes, secretos en texto plano, bug de `API_BASE_URL` en el cliente web) y un build en limpio dentro de un contenedor `gradle:8.14-jdk21` (8 servicios compilan, 10 de 50 pruebas fallan). Con eso redactó [`docs/agil/PLAN-PROYECTO.md`](docs/agil/PLAN-PROYECTO.md), reorganizado en Sprint 0, 1 y 2 con pasos por entregable.
- **Verificación / cambios del equipo:** se pidió reestructurar la primera versión porque no estaba dividida en sprints formales. Los fallos de las pruebas se comprobaron con los reportes JUnit del build.

### 2026-11-04 · `jmrojas06` · Backlog y tablero

- **Prompts:** *"Listo, y entonces en el backlog lo que vaya a hacer mi amigo. No te incluyas en los commits como colaborador porfavor…"*
- **Qué produjo:** 34 issues (7 tareas del Sprint 0 y 27 historias de usuario con criterios de aceptación y story points), etiquetas por entregable y responsable, milestones por sprint y el [tablero de GitHub Projects](https://github.com/orgs/ingesoft5/projects/8) con campos Status, Sprint, Story Points y Entregable.
- **Verificación / cambios del equipo:** se revisó que el reparto quedara equilibrado (26 puntos propios por integrante en el Sprint 1). El responsable B se confirmó como `pierrecuevas`.

### 2026-11-04 · `jmrojas06` · Estrategia de ramas y Sprint 0

- **Prompts:** *"Sí, arranca"* y *"Terminemos todo mi sprint 0, y se lo pasas para el review a mi amigo. Y que luego el haga su sprint 0 y me lo pase a mi para revision pr."* El equipo también preguntó si se cumplía el requisito de branching del enunciado.
- **Qué produjo:** [`CONTRIBUTING.md`](CONTRIBUTING.md) (GitHub Flow, Conventional Commits, protección de `main`, DoD), [`docs/agil/sprint-0.md`](docs/agil/sprint-0.md) con el planning del Sprint 1, el renombre del repositorio, la protección de `main` vía API (con evidencia en `docs/evidencias/sprint-0/`) y este registro.
- **Verificación / cambios del equipo:** _por completar por el revisor del PR._

### 2026-11-04 · `jmrojas06` · Revisión de la rúbrica

- **Prompt:** *"Revisa la rubrica, busca rubrica en todas partes para asegurar que saquemos 5. Tambien mantener al final en gitignore nuestros guiones y todo lo que hemos hecho para estudiar y sustentar."*
- **Qué produjo:** comparación del PDF con el `.tex` (idénticos), revisión del repo base del docente y de los READMEs de los talleres del curso, una checklist privada criterio por criterio, 2 historias nuevas (#38 burndown, #39 bonos), criterios agregados a 20 issues (marcados "(rúbrica)"), review y retro del Sprint 0 en borrador y la carpeta `estudio/` excluida de git.
- **Hallazgos clave:** el criterio P1.8 exige un **video** que el entregable E1.8 no menciona; la Parte 1 pide el primer release como `v1.0.0`, pipeline accesible al docente y evidencia por entregable.
- **Verificación / cambios del equipo:** _por completar por el revisor del PR._

### 2026-11-04 · `pierrecuevas` · Plantillas de PR e issues (#4)

- **Contenido propio entregado:** la sección de metodología del enunciado y el backlog/tablero ya creados por el equipo.
- **Prompt:** *"Este es el proyecto de ingesoft, mi amigo ya cuadro el github projects y los issues, entonces la idea es que yo ya termine el sprint #0, lo que me falta, y hacer el pr para que mi compañero lo haga."* (+ requisitos de branching del enunciado)
- **Qué produjo:** `.github/pull_request_template.md` (título como Conventional Commit, `Closes #`, tipo de cambio con su efecto en semver, checklist alineado con la DoD) y `.github/ISSUE_TEMPLATE/{historia,bug,solicitud-cambio}.md` + `config.yml`. La solicitud de cambio usa la clasificación estándar/normal/emergencia del plan (paso 1.6).
- **Verificación / cambios del equipo:** _por completar por el revisor del PR._

### 2026-11-04 · `pierrecuevas` · Código base limpio y en verde (#6)

- **Prompt:** el mismo de la entrada anterior (terminar el Sprint 0 de B).
- **Qué produjo:** limpieza del repo (C1-C3), wrapper de Gradle versionado y la corrección de las 10 pruebas rotas. Diagnosticó cada fallo con los reportes JUnit antes de tocar código: en promotion concluyó que el error estaba en la prueba (rol sin prefijo `ROLE_`) y no en el controlador, comparándolo con los *claims* que emite auth. Encontró que Testcontainers fallaba por la versión de la API de Docker, no por falta de Docker.
- **Verificación / cambios del equipo:** build completo desde un `git clone` limpio en `gradle:8.14-jdk21`: 52 pruebas, 0 fallas ([evidencia](docs/evidencias/sprint-0/build-verde.txt)). _Cambios del revisor: por completar._

---

## Reflexión crítica del equipo

_Se completa al cierre de cada sprint (en la retrospectiva): qué aportó la IA, qué errores cometió y cómo se detectaron, qué decisiones se tomaron en contra de su sugerencia y qué aprendimos haciendo el trabajo nosotros._
