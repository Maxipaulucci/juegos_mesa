# Build Spring Boot
FROM maven:3.9-eclipse-temurin-17 AS spring-build
WORKDIR /build
COPY spring/pom.xml .
COPY spring/src ./src
RUN mvn -q -DskipTests package

# Runtime: Java + Node en un solo contenedor
FROM eclipse-temurin:17-jre-jammy

RUN apt-get update \
  && apt-get install -y curl ca-certificates gnupg \
  && mkdir -p /etc/apt/keyrings \
  && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
     | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
  && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" \
     > /etc/apt/sources.list.d/nodesource.list \
  && apt-get update \
  && apt-get install -y nodejs \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=spring-build /build/target/salas-api-*.jar ./spring/
COPY mongo/package.json ./mongo/
RUN cd mongo && npm install --omit=dev
COPY mongo/src ./mongo/src
COPY start.sh .
RUN chmod +x start.sh

ENV SPRING_PORT=8080
ENV PORT=10000

EXPOSE 10000

CMD ["./start.sh"]
