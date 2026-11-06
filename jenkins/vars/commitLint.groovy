// Valida Conventional Commits con commitlint (config en commitlint.config.cjs).
//  - PR: el título del PR (es el mensaje que queda en main al hacer squash) y cada commit del PR.
//  - main: el último commit.
// Los mensajes se sacan con git en Jenkins y se validan dentro de un contenedor de Node.
def call() {
    String range = env.CHANGE_TARGET ? "origin/${env.CHANGE_TARGET}..HEAD" : 'HEAD~1..HEAD'
    sh "rm -rf .commitlint && mkdir -p .commitlint/msgs"
    if (env.CHANGE_TITLE) {
        writeFile file: '.commitlint/msgs/00-titulo-del-pr.txt', text: env.CHANGE_TITLE + '\n'
    }
    // Un archivo por commit; los merge commits se omiten.
    sh """git log --no-merges --format='%H' ${range} 2>/dev/null | while read -r sha; do
            git log -1 --format='%B' "\$sha" > ".commitlint/msgs/\${sha}.txt"
          done; ls .commitlint/msgs | wc -l | xargs echo '[commitLint] mensajes a validar:'"""
    docker.image('node:22.23.4-alpine').inside('--entrypoint=') {
        sh '''set -e
            export HOME="$WORKSPACE/.commitlint" npm_config_cache="$WORKSPACE/.commitlint/npm"
            cd .commitlint
            npm install --silent --no-audit --no-fund @commitlint/cli@21.2.4 @commitlint/config-conventional@21.2.4 >/dev/null
            cp ../commitlint.config.cjs .
            fail=0
            for f in msgs/*.txt; do
              [ -e "$f" ] || continue
              if npx --no-install commitlint < "$f"; then echo "✓ $(head -1 "$f")"; else fail=1; fi
            done
            exit $fail'''
    }
}
