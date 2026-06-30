FROM eclipse-temurin:17-jre-alpine
VOLUME /tmp
EXPOSE 80
COPY target/*.jar app.jar
ENV JAVA_OPTS=""

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app.jar"]