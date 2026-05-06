---
name: create-spring-boot-project
description: Creates Spring Boot Java project skeleton with Java 21, Docker, Maven, and essential dependencies. Use when starting a new Spring Boot project, initializing Java project, or scaffolding Spring Boot application.
version: "1.0.0"
---

# Create Spring Boot Java Project

Creates a production-ready Spring Boot Java project skeleton.

## Prerequisites

- Java 21
- Docker
- Docker Compose

## Workflow

### 1. Download Template

```bash
curl https://start.spring.io/starter.zip \
  -d artifactId=demo-java \
  -d bootVersion=3.5.14 \
  -d dependencies=lombok,configuration-processor,web,postgresql,data-redis,validation,cache,testcontainers \
  -d javaVersion=21 \
  -d packageName=com.example \
  -d packaging=jar \
  -d type=maven-project \
  -o starter.zip

unzip starter.zip -d ./demo-java
rm starter.zip
cd demo-java
```

### 2. Add Dependencies

```xml
<!-- MyBatis-Plus -->
<dependency>
  <groupId>com.baomidou</groupId>
  <artifactId>mybatis-plus-spring-boot3-starter</artifactId>
  <version>3.5.9</version>
</dependency>
<!-- Database Driver -->
<dependency>
  <groupId>org.postgresql</groupId>
  <artifactId>postgresql</artifactId>
  <scope>runtime</scope>
</dependency>
<!-- OpenAPI Documentation -->
<dependency>
  <groupId>org.springdoc</groupId>
  <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
  <version>2.8.6</version>
</dependency>
<!-- Architecture Testing -->
<dependency>
  <groupId>com.tngtech.archunit</groupId>
  <artifactId>archunit-junit5</artifactId>
  <version>1.2.1</version>
  <scope>test</scope>
</dependency>
```

### 3. Configuration

```yaml
# application.yml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/demo
    username: postgres
    password: postgres
    driver-class-name: org.postgresql.Driver
  data:
    redis:
      host: localhost
      port: 6379

mybatis-plus:
  configuration:
    map-underscore-to-camel-case: true
    log-impl: org.apache.ibatis.logging.stdout.StdOutImpl
  global-config:
    db-config:
      id-type: auto
      logic-delete-field: deleted
      logic-delete-value: 1
      logic-not-delete-value: 0

springdoc:
  swagger-ui:
    doc-expansion: none
```

### 4. Docker Compose

```yaml
services:
  postgres:
    image: postgres:17
    ports: ["5432:5432"
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: demo
  redis:
    image: redis:7
    ports: ["6379:6379"
```

### 5. Validate

```bash
./mvnw clean test
docker-compose up -d
./mvnw spring-boot:run
```
