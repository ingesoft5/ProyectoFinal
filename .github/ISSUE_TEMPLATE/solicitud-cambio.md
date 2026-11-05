---
name: Solicitud de cambio
about: Cambio que afecta un ambiente desplegado (stage o prod) y requiere aprobación formal
title: "RFC: "
labels: ["change-request"]
assignees: []
---

## Cambio solicitado

<!-- Qué se va a cambiar y por qué. -->

## Clasificación

- [ ] **Estándar** — bajo riesgo y repetible (dependencia menor, documentación). Aprueba 1 revisor.
- [ ] **Normal** — `feat` / `fix`. Aprueba 1 revisor + aprobación manual (`input`) para prod.
- [ ] **Emergencia** — caída en prod. Rama `hotfix/*`; aprobación posterior en máximo 24 h.

## Alcance

| Campo | Valor |
|---|---|
| Servicios afectados | |
| Ambientes | dev / stage / prod |
| Versión actual → nueva | `vX.Y.Z` → `vX.Y.Z` |
| PR relacionado | # |
| Ventana de despliegue | |

## Riesgo e impacto

<!-- Qué puede fallar y a quién afecta. -->

## Plan de pruebas

<!-- Qué pruebas (unitarias, integración, E2E, smoke) validan el cambio. -->

## Plan de rollback

<!-- Normalmente: redesplegar la versión anterior con el job de rollback. Indicar la versión destino. -->

## Aprobación

- [ ] Aprobado por: 
- [ ] Desplegado y verificado en: 
