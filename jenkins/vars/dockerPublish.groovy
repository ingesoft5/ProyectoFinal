// Construye y publica en Nexus la imagen de un servicio con tag de versión y de commit.
// Nunca usa "latest". Si el servicio aún no tiene Dockerfile (HU-02), lo omite con aviso.
// Uso: dockerPublish('circleguard-auth-service', '1.2.0')
def call(String svc, String version) {
    String dir = svc == 'web' ? 'mobile' : "services/${svc}"
    if (!fileExists("${dir}/Dockerfile")) {
        echo "[dockerPublish] ${svc}: sin Dockerfile todavía, se omite"
        return null
    }
    String name = svc == 'web' ? 'circleguard-web' : svc
    String image = "${env.REGISTRY}/circleguard/${name}"
    String sha = env.GIT_COMMIT.take(7)
    withCredentials([usernamePassword(credentialsId: 'nexus-ci', usernameVariable: 'NX_USER', passwordVariable: 'NX_PASS')]) {
        withEnv(["IMAGE=${image}", "VERSION=${version}", "SHA=${sha}", "CTX=${dir}"]) {
            sh '''echo "$NX_PASS" | docker login --username "$NX_USER" --password-stdin "$REGISTRY" >/dev/null
                docker build --pull -t "$IMAGE:$VERSION" -t "$IMAGE:sha-$SHA" \
                  --label org.opencontainers.image.version="$VERSION" \
                  --label org.opencontainers.image.revision="$GIT_COMMIT" \
                  --label org.opencontainers.image.source="$GIT_URL" "$CTX"
                docker push "$IMAGE:$VERSION"
                docker push "$IMAGE:sha-$SHA"
                docker image ls "$IMAGE" --format '{{.Repository}}:{{.Tag}} {{.Size}}' | head -2'''
        }
    }
    return "${image}:${version}"
}
