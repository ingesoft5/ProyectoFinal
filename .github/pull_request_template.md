<!--
Título del PR = Conventional Commit, porque es el mensaje que queda en main al hacer squash.
Ejemplo: feat(promotion): agrega cascada de estados con TTL de 14 dias
-->

## Qué cambia

<!-- Resumen en 2-4 líneas: qué y por qué. -->

Closes #

## Tipo de cambio

- [ ] `feat` — funcionalidad nueva (MINOR)
- [ ] `fix` / `perf` — corrección (PATCH)
- [ ] `feat!` / `BREAKING CHANGE` (MAJOR)
- [ ] `docs` / `test` / `ci` / `build` / `chore` / `refactor` (sin release)

## Cómo se probó

<!-- Comandos, pruebas nuevas, capturas. -->

## Checklist del autor

- [ ] El título y los commits siguen [Conventional Commits](https://github.com/ingesoft5/circle-guard-finalproject-A00405392-A00405468/blob/main/CONTRIBUTING.md#2-conventional-commits).
- [ ] La rama sigue `<tipo>/<issue>-<descripcion>`.
- [ ] Cumple los criterios de aceptación del issue.
- [ ] Hay evidencia en `docs/evidencias/sprint-N/` (si aplica).
- [ ] La documentación afectada está actualizada.
- [ ] Si usé IA generativa, quedó registrada en `IAG_REGISTRO.md` en este mismo PR.
- [ ] No hay secretos ni credenciales reales en el cambio.

## Para el revisor

- [ ] Revisé el cambio contra los criterios de aceptación, no solo el código.
- [ ] El check de Jenkins está en verde.
