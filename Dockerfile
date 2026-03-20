FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY petclinic-app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]