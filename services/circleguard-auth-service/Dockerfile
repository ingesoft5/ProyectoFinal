# syntax=docker/dockerfile:1
# Imagen de circleguard-auth-service. Se construye desde la RAÍZ del repo (monorepo Gradle):
#   docker build -f services/circleguard-auth-service/Dockerfile -t circleguard-auth-service:<versión> .

# --- Etapa 1: compilación ---------------------------------------------------------
FROM gradle:8.14-jdk21 AS build
WORKDIR /workspace
COPY settings.gradle.kts build.gradle.kts ./
COPY services/circleguard-auth-service services/circleguard-auth-service
# Caché de dependencias de Gradle entre builds (BuildKit). Las pruebas corren en el pipeline, no aquí.
RUN --mount=type=cache,target=/home/gradle/.gradle \
    gradle :services:circleguard-auth-service:bootJar --no-daemon --console=plain -x test \
 && find services/circleguard-auth-service/build/libs -name '*.jar' ! -name '*-plain.jar' -exec cp {} /workspace/app.jar \;

# --- Etapa 2: ejecución (solo JRE, usuario sin privilegios) -----------------------
FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S app && adduser -S -G app -H -s /sbin/nologin app
WORKDIR /app
COPY --from=build --chown=app:app /workspace/app.jar app.jar
USER app
ENV SERVER_PORT=8180 \
    JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError"
EXPOSE 8180
HEALTHCHECK --interval=15s --timeout=5s --start-period=90s --retries=5 \
  CMD wget -q -O /dev/null "http://127.0.0.1:${SERVER_PORT}/actuator/health/readiness" || exit 1
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
