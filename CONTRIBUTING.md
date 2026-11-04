# Guía de contribución — CircleGuard

Reglas de trabajo del equipo (`jmrojas06`, `pierrecuevas`). Aplican a todo cambio en este repositorio, incluida la documentación.

## 1. Estrategia de ramas: GitHub Flow

```
main ──●────────●────────●──────────●───▶  (siempre desplegable, protegida)
        \      /  \     /    \     /
         feat/…    fix/…      ci/…        (ramas cortas, 1 tarea cada una)
```

- **`main`** es la única rama de larga vida. Todo lo que está en `main` pasó revisión y pipeline, y el pipeline lo despliega a `dev`.
- El trabajo se hace en **ramas cortas** creadas desde `main` y se integra con un **pull request**.
- Los ambientes (`dev` → `stage` → `prod`) **no son ramas**: el pipeline promueve la **misma imagen** versionada de un ambiente al siguiente.

**¿Por qué GitHub Flow?** Somos 2 integrantes con sprints de días. GitFlow (`develop`, `release/*`, `hotfix/*`) agrega ramas y *merges* que no aportan con este tamaño de equipo. *Trunk-based* puro exige *feature flags* desde el día 1. GitHub Flow da una sola fuente de verdad, PR revisados y despliegue continuo desde `main`.

### Nombres de rama

`<tipo>/<issue>-<descripcion-corta>`, con el mismo tipo que el commit principal:

| Tipo | Uso | Ejemplo |
|---|---|---|
| `feat/` | Funcionalidad nueva | `feat/15-promocion-stage` |
| `fix/` | Corrección | `fix/6-identity-tests` |
| `ci/` | Pipeline, Jenkins | `ci/11-jenkinsfile` |
| `build/` | Dockerfiles, Gradle, compose | `build/9-dockerfiles` |
| `test/` | Pruebas | `test/14-playwright` |
| `docs/` | Documentación | `docs/3-contributing` |
| `chore/` | Mantenimiento | `chore/6-limpieza-repo` |
| `hotfix/` | Emergencia en producción (ver política de cambios) | `hotfix/fix-qr-expiracion` |

## 2. Conventional Commits

Formato: `<tipo>(<alcance>)<!>: <descripción en minúscula, imperativo>`

- **Tipos:** `feat`, `fix`, `perf`, `refactor`, `test`, `build`, `ci`, `docs`, `chore`, `revert`.
- **Alcances:** `auth`, `identity`, `promotion`, `notification`, `form`, `file`, `gateway`, `dashboard`, `web`, `infra`, `jenkins`, `deploy`, `k8s`, `observability`, `agile`.

Cada commit alimenta el **versionado semántico automático** (semantic-release en Jenkins):

| Commit | Efecto en la versión | Ejemplo |
|---|---|---|
| `fix:` / `perf:` | PATCH `1.2.3 → 1.2.4` | `fix(gateway): corrige expiracion de QR firmado` |
| `feat:` | MINOR `1.2.3 → 1.3.0` | `feat(promotion): agrega cascada de estados con TTL de 14 dias` |
| `feat!:` o pie `BREAKING CHANGE:` | MAJOR `1.2.3 → 2.0.0` | `feat(auth)!: reemplaza esquema de roles` |
| `docs`, `test`, `ci`, `build`, `chore`, `refactor` | Sin release | `ci(jenkins): agrega etapa de sonar` |

El pipeline valida los mensajes con **commitlint**: un PR con commits que no cumplen el formato no pasa el check.

## 3. Pull requests

1. Crear un issue o tomar uno del tablero y moverlo a **In progress**.
2. `git switch -c <tipo>/<issue>-<descripcion>` desde `main` actualizado.
3. Commits pequeños con Conventional Commits.
4. Abrir el PR con la plantilla. El **título del PR también es un Conventional Commit**, porque es el mensaje que queda en `main` al hacer *squash*. Incluir `Closes #<issue>`.
5. Pedir revisión al otro integrante y mover la tarjeta a **Review**.
6. Fusionar solo cuando:
   - el otro integrante lo **aprobó** (nunca el propio autor);
   - el **check de Jenkins** está en verde (build, pruebas, cobertura, SonarQube, quality gate);
   - no hay conversaciones abiertas.
7. **Squash and merge** y borrar la rama.

### Revisión
- Revisar contra los criterios de aceptación del issue, no solo el código.
- Comentar de forma concreta: qué cambiar y por qué. Una aprobación sin leer el cambio no cuenta.
- Responder una revisión en máximo medio día durante los sprints.

## 4. Protección de `main`

| Regla | Valor |
|---|---|
| Cambios directos (*push*) a `main` | Prohibidos |
| PR obligatorio | Sí |
| Aprobaciones requeridas | 1, de un integrante distinto al autor |
| Descartar aprobaciones si llegan commits nuevos | Sí |
| Checks obligatorios | `continuous-integration/jenkins/pr-merge` (desde HU-04) |
| Rama actualizada con `main` antes de fusionar | Sí |
| Método de fusión | Solo *squash* |
| *Force push* y borrado de `main` | Prohibidos |

## 5. Definición de Terminado (DoD)

Un issue pasa a **Done** cuando:
- [ ] Está en `main` mediante un PR aprobado por el otro integrante.
- [ ] El pipeline está en verde.
- [ ] Cumple todos sus criterios de aceptación.
- [ ] Hay evidencia (captura o enlace a la ejecución) en `docs/evidencias/sprint-N/`.
- [ ] La documentación afectada está actualizada.

## 6. Uso de IA generativa

Política del curso: **Nivel 3, colaboración con IAG**. Todo prompt usado se registra en `IAG_REGISTRO.md` en el mismo PR donde se usa su resultado. Quien abre el PR debe poder explicar y modificar todo lo que contiene.
