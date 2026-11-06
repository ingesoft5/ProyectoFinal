// Corre tareas de Gradle solo en los servicios indicados.
// Uso: runGradle(['circleguard-auth-service'], ['test'])  →  ./gradlew :services:circleguard-auth-service:test
// El cliente web ("web") no es un proyecto Gradle y se ignora aquí.
def call(List services, List tasks, String extraArgs = '') {
    List projects = services.findAll { it != 'web' }
    if (!projects) {
        echo "[runGradle] Ningún servicio Java para: ${tasks.join(', ')}"
        return
    }
    String targets = projects.collectMany { svc -> tasks.collect { ":services:${svc}:${it}" } }.join(' ')
    sh "./gradlew ${targets} --no-daemon --continue --console=plain ${extraArgs}"
}

// Servicios que definen una tarea concreta en su build.gradle.kts (p. ej. integrationTest).
List withTask(List services, String task) {
    services.findAll { svc ->
        svc != 'web' && sh(script: "grep -q '${task}' services/${svc}/build.gradle.kts", returnStatus: true) == 0
    }
}
