// Analiza un servicio en SonarQube y espera su quality gate: si no pasa, el build falla.
// Cada servicio es un proyecto propio en SonarQube ("circleguard-auth-service", ...).
def call(String svc) {
    String dir = "services/${svc}"
    withSonarQubeEnv('sonarqube') {
        // El contenedor del scanner va en la red de las herramientas para llegar a http://sonarqube:9000.
        docker.image('sonarsource/sonar-scanner-cli:12.2').inside('--network circleguard-tools_default --entrypoint=') {
            withEnv(["SVC=${svc}", "DIR=${dir}", "SONAR_USER_HOME=${env.WORKSPACE}/.sonar"]) {
                sh '''sonar-scanner \
                    -Dsonar.host.url="$SONAR_HOST_URL" -Dsonar.token="$SONAR_AUTH_TOKEN" \
                    -Dsonar.projectKey="$SVC" -Dsonar.projectName="CircleGuard · $SVC" \
                    -Dsonar.projectVersion="${BUILD_VERSION:-$GIT_COMMIT}" \
                    -Dsonar.sources="$DIR/src/main" -Dsonar.tests="$DIR/src/test" \
                    -Dsonar.java.binaries="$DIR/build/classes/java/main" \
                    -Dsonar.java.test.binaries="$DIR/build/classes/java/test" \
                    -Dsonar.junit.reportPaths="$DIR/build/test-results/test" \
                    -Dsonar.coverage.jacoco.xmlReportPaths="$DIR/build/reports/jacoco/test/jacocoTestReport.xml" \
                    -Dsonar.scm.disabled=true -Dsonar.qualitygate.wait=false'''
            }
        }
    }
    timeout(time: 10, unit: 'MINUTES') {
        def qg = waitForQualityGate()
        if (qg.status != 'OK') {
            error "Quality gate de ${svc}: ${qg.status}. Revisa ${env.SONAR_HOST_URL ?: 'SonarQube'}/dashboard?id=${svc}"
        }
        echo "[sonarScan] ${svc}: quality gate ${qg.status}"
    }
}
