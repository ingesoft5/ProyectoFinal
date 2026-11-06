// Pipeline de CircleGuard. Multibranch: corre en cada PR (CI) y en main (CI + publicación).
// Las etapas reutilizables viven en la Shared Library de jenkins/ (cargada desde la misma rama).
library "circleguard@${env.CHANGE_BRANCH ?: env.BRANCH_NAME}"

// Variable del binding del script: visible desde todas las etapas.
SERVICES = []

pipeline {
    agent any

    options {
        timestamps()
        ansiColor('xterm')
        disableConcurrentBuilds(abortPrevious: true)
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timeout(time: 60, unit: 'MINUTES')
    }

    environment {
        GRADLE_OPTS = '-Dorg.gradle.daemon=false -Dorg.gradle.jvmargs=-Xmx1536m'
        // Versión provisional hasta HU-09 (#16), que la calcula semantic-release.
        BUILD_VERSION = "0.0.0-build.${env.BUILD_NUMBER}"
    }

    stages {
        stage('Preparar') {
            steps {
                script {
                    SERVICES = changedServices()
                    currentBuild.description = SERVICES ? "Servicios: ${SERVICES.join(', ')}" : 'Sin cambios en servicios'
                }
            }
        }

        stage('Commitlint') {
            steps { commitLint() }
        }

        stage('Build') {
            when { expression { !SERVICES.isEmpty() } }
            steps { runGradle(SERVICES, ['classes', 'testClasses']) }
        }

        stage('Unit tests + JaCoCo') {
            when { expression { !SERVICES.isEmpty() } }
            steps { runGradle(SERVICES, ['test', 'jacocoTestReport']) }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'services/*/build/test-results/test/*.xml'
                    recordCoverage tools: [[parser: 'JACOCO', pattern: 'services/*/build/reports/jacoco/test/jacocoTestReport.xml']],
                                   id: 'jacoco', name: 'Cobertura JaCoCo', sourceCodeRetention: 'EVERY_BUILD'
                }
            }
        }

        stage('SonarQube + Quality Gate') {
            when { expression { SERVICES.any { it != 'web' } } }
            steps {
                script {
                    SERVICES.findAll { it != 'web' }.each { svc -> sonarScan(svc) }
                }
            }
        }

        stage('Integration tests') {
            when { expression { !runGradle.withTask(SERVICES, 'integrationTest').isEmpty() } }
            steps { runGradle(runGradle.withTask(SERVICES, 'integrationTest'), ['integrationTest']) }
            post {
                always { junit allowEmptyResults: true, testResults: 'services/*/build/test-results/integrationTest/*.xml' }
            }
        }

        stage('Package + Publish') {
            when {
                allOf {
                    branch 'main'
                    expression { !SERVICES.isEmpty() }
                }
            }
            steps {
                script {
                    def published = SERVICES.collect { svc -> dockerPublish(svc, env.BUILD_VERSION) }.findAll { it }
                    echo published ? "Imágenes publicadas:\n${published.join('\n')}" : 'Ninguna imagen publicada (faltan Dockerfiles)'
                }
            }
        }
    }

    post {
        failure { notifyTeam('FAILURE') }
        fixed { notifyTeam('SUCCESS', "El pipeline volvió a verde en ${env.BRANCH_NAME}.") }
        cleanup { sh 'rm -rf .commitlint .sonar .scannerwork || true' }
    }
}
