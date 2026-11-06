// Conventional Commits del equipo (ver CONTRIBUTING.md §2). Lo usa el stage "Commitlint" del pipeline.
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'header-max-length': [2, 'always', 100],
    // El cuerpo de los squash de GitHub trae líneas largas (lista de commits): no se limita.
    'body-max-line-length': [0],
    'footer-max-line-length': [0],
  },
};
