// Devuelve los servicios a construir en este build (ejecución selectiva).
//  - PR: lo que cambió respecto a la rama destino.
//  - main: lo que cambió desde el último build exitoso (o el último commit).
//  - Si cambió algo común (Gradle, Jenkinsfile, Shared Library) se construyen todos.
// Nombres = carpetas de services/ (p. ej. "circleguard-auth-service") y "web" para mobile/.
List call() {
    List all = sh(script: 'ls -d services/*/ | xargs -n1 basename', returnStdout: true).trim().split('\n') as List
    all << 'web'
    String base = baseRef()
    if (!base) {
        echo '[changedServices] Sin referencia para comparar: se construyen todos'
        return all
    }
    List files = sh(script: "git diff --name-only ${base} HEAD", returnStdout: true).trim().split('\n').findAll { it }
    def global = ~/^(build\.gradle\.kts|settings\.gradle\.kts|gradle\/.*|gradlew|Jenkinsfile|jenkins\/.*)$/
    if (files.any { it ==~ global }) {
        echo '[changedServices] Cambió configuración común: se construyen todos'
        return all
    }
    List selected = all.findAll { svc ->
        String dir = svc == 'web' ? 'mobile/' : "services/${svc}/"
        files.any { it.startsWith(dir) }
    }
    echo "[changedServices] Archivos cambiados: ${files.size()} → servicios: ${selected ?: 'ninguno'}"
    return selected
}

private String baseRef() {
    if (env.CHANGE_TARGET) {
        // En un PR solo está la rama del PR: se trae la rama destino para comparar.
        withCredentials([usernamePassword(credentialsId: 'github-token', usernameVariable: 'GH_USER', passwordVariable: 'GH_TOKEN')]) {
            sh '''git fetch --no-tags --quiet "https://${GH_USER}:${GH_TOKEN}@github.com/$(git config --get remote.origin.url | sed -E 's#.*github.com[/:]##; s#\\.git$##').git" \
                  "+refs/heads/${CHANGE_TARGET}:refs/remotes/origin/${CHANGE_TARGET}"'''
        }
        return sh(script: "git merge-base origin/${env.CHANGE_TARGET} HEAD", returnStdout: true).trim()
    }
    String prev = env.GIT_PREVIOUS_SUCCESSFUL_COMMIT
    if (prev && sh(script: "git cat-file -e ${prev}^{commit}", returnStatus: true) == 0) {
        return prev
    }
    return sh(script: 'git rev-parse --verify --quiet HEAD~1', returnStatus: true) == 0 ? 'HEAD~1' : null
}
