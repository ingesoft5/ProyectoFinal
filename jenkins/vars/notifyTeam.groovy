// Avisa al equipo por WhatsApp (CallMeBot) y Discord con el resultado del build.
// Uso en el Jenkinsfile:
//   post { failure { notifyTeam('FAILURE') }  success { notifyTeam('SUCCESS', "Desplegado ${version} en prod") } }
//   notifyTeam('APPROVAL', "v${version} espera aprobación para prod")
def call(String status, String detail = '') {
    def title = "${env.JOB_NAME} #${env.BUILD_NUMBER}"
    def text = detail ?: defaultDetail(status)
    writeFile file: '.notify.sh', text: libraryResource('scripts/notify.sh')
    withCredentials([
        string(credentialsId: 'whatsapp-recipients', variable: 'WHATSAPP_RECIPIENTS'),
        string(credentialsId: 'discord-webhook', variable: 'DISCORD_WEBHOOK_URL'),
    ]) {
        // Los argumentos van por variables de entorno para no romper el shell con comillas.
        withEnv(["N_STATUS=${status}", "N_TITLE=${title}", "N_DETAIL=${text}", "N_LINK=${env.BUILD_URL ?: ''}"]) {
            sh 'bash .notify.sh "$N_STATUS" "$N_TITLE" "$N_DETAIL" "$N_LINK"; rm -f .notify.sh'
        }
    }
}

private String defaultDetail(String status) {
    def branch = env.BRANCH_NAME ?: 'sin rama'
    switch (status) {
        case 'FAILURE': return "Falló en la rama ${branch}. Revisa la etapa en rojo."
        case 'SUCCESS': return "Pipeline en verde en la rama ${branch}."
        case 'UNSTABLE': return "Pipeline inestable en la rama ${branch} (pruebas o calidad)."
        case 'ABORTED': return "Pipeline cancelado en la rama ${branch}."
        default: return "Rama ${branch}."
    }
}
