FROM maven:3.8.8-amazoncorretto-17 as build
WORKDIR /app
# Copy pom.xml to the build context
COPY pom.xml .
# Download dependencies
RUN mvn dependency:go-offline
# Copy the actual source code from the backend folder
COPY backend/src ./src
# Build the application
RUN mvn package -DskipTests
# Runtime image
FROM openjdk:17-jdk-slim
WORKDIR /app
# Copy the jar from the build stage
COPY --from=build /app/target/ecommerce-1.0-SNAPSHOT.jar ./app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
