# Module pom.xml Templates

Full pom.xml templates for each module. Only dependency declarations — no plugins, no exclusions. Plugin configuration belongs in the parent POM.

## parent/pom.xml

```xml
<properties>
    <java.version>21</java.version>
    <!-- Use latest Spring Boot 3.5.x version for your project -->
    <spring-boot.version>3.5.x</spring-boot.version>
    <!-- Spring Cloud Alibaba version must match Spring Boot version - see compatibility matrix at https://github.com/alibaba/spring-cloud-alibaba/wiki/版本说明 -->
    <spring-cloud-alibaba.version>2025.0.0.0-RC1</spring-cloud-alibaba.version>
    <mapstruct.version>1.6.3</mapstruct.version>
    <springdoc.version>2.8.16</springdoc.version>
</properties>

<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-dependencies</artifactId>
            <version>${spring-boot.version}</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
        <dependency>
            <groupId>com.alibaba.cloud</groupId>
            <artifactId>spring-cloud-alibaba-dependencies</artifactId>
            <version>${spring-cloud-alibaba.version}</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
        <!-- SpringDoc BOM transitively manages swagger-annotations-jakarta and swagger-core versions.
             Do NOT pin swagger-annotations-jakarta version directly — let SpringDoc BOM drive it. -->
        <dependency>
            <groupId>org.springdoc</groupId>
            <artifactId>springdoc-openapi-bom</artifactId>
            <version>${springdoc.version}</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>

<modules>
    <module>demo-client</module>
    <module>demo-adapter</module>
    <module>demo-app</module>
    <module>demo-domain</module>
    <module>demo-infrastructure</module>
    <module>demo-start</module>
</modules>
```

## client/pom.xml

```xml
<dependencies>
    <dependency>
        <groupId>jakarta.validation</groupId>
        <artifactId>jakarta.validation-api</artifactId>
    </dependency>
    <dependency>
        <groupId>org.projectlombok</groupId>
        <artifactId>lombok</artifactId>
        <scope>provided</scope>
    </dependency>
    <!-- OpenFeign: provided scope — other services bring their own Feign runtime -->
    <dependency>
        <groupId>org.springframework.cloud</groupId>
        <artifactId>spring-cloud-starter-openfeign</artifactId>
        <scope>provided</scope>
    </dependency>
    <!-- OpenAPI 3 annotations for Cmd/Qry/DTO — provided scope, adapter brings runtime -->
    <dependency>
        <groupId>io.swagger.core.v3</groupId>
        <artifactId>swagger-annotations-jakarta</artifactId>
        <scope>provided</scope>
    </dependency>
</dependencies>
```

> OpenFeign is `provided` scope — client module only needs the annotation for compilation. Other services bring the Feign runtime themselves.
> swagger-annotations-jakarta is `provided` scope — adapter module (with springdoc-openapi-starter-webmvc-ui) brings the runtime.
> No COLA component dependency — Result/PageResult/BusinessException/Command/Query are defined in client `common/` package.

## domain/pom.xml

```xml
<dependencies>
    <dependency>
        <groupId>${project.groupId}</groupId>
        <artifactId>demo-client</artifactId>
        <version>${project.version}</version>
    </dependency>
    <dependency>
        <groupId>org.projectlombok</groupId>
        <artifactId>lombok</artifactId>
        <scope>provided</scope>
    </dependency>
</dependencies>
```

> Domain depends on nothing except client (for Result/BusinessException base types). No Spring, no MyBatis, no infrastructure tech. Pure Java + Lombok.

## infrastructure/pom.xml

```xml
<dependencies>
    <dependency>
        <groupId>${project.groupId}</groupId>
        <artifactId>demo-domain</artifactId>
        <version>${project.version}</version>
    </dependency>
    <dependency>
        <groupId>com.baomidou</groupId>
        <artifactId>mybatis-plus-spring-boot3-starter</artifactId>
    </dependency>
    <dependency>
        <groupId>org.postgresql</groupId>
        <artifactId>postgresql</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-data-redis</artifactId>
    </dependency>
    <!-- OPTIONAL: RestClient for external HTTP calls (Spring 6.1+).
         Add ONLY when infrastructure has gatewayimpl/rpc/ for calling external services.
         Pure-CRUD services without external HTTP calls do not need this. -->
    <!--
    <dependency>
        <groupId>org.springframework</groupId>
        <artifactId>spring-web</artifactId>
    </dependency>
    -->
    <!-- OPTIONAL: Jackson Java 8 date/time support (LocalDateTime, etc.).
         Add ONLY when infrastructure has custom JacksonConfig (see spring-boot-jackson-config skill).
         Adapter module's spring-boot-starter-web already provides this transitively for HTTP layer. -->
    <!--
    <dependency>
        <groupId>com.fasterxml.jackson.datatype</groupId>
        <artifactId>jackson-datatype-jsr310</artifactId>
    </dependency>
    -->
    <dependency>
        <groupId>org.mapstruct</groupId>
        <artifactId>mapstruct</artifactId>
        <version>${mapstruct.version}</version>
    </dependency>
    <dependency>
        <groupId>org.mapstruct</groupId>
        <artifactId>mapstruct-processor</artifactId>
        <version>${mapstruct.version}</version>
        <scope>provided</scope>
    </dependency>
</dependencies>
```

## app/pom.xml

```xml
<dependencies>
    <dependency>
        <groupId>${project.groupId}</groupId>
        <artifactId>demo-client</artifactId>
        <version>${project.version}</version>
    </dependency>
    <dependency>
        <groupId>${project.groupId}</groupId>
        <artifactId>demo-infrastructure</artifactId>
        <version>${project.version}</version>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter</artifactId>
    </dependency>
</dependencies>
```

> app depends on infrastructure for the **read path** (QryExe accesses Mapper directly). This is a pragmatic exception — write path still goes through Domain Gateway.

## adapter/pom.xml

```xml
<dependencies>
    <dependency>
        <groupId>${project.groupId}</groupId>
        <artifactId>demo-app</artifactId>
        <version>${project.version}</version>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <!-- Validation: triggers @NotBlank/@NotNull on Cmd/Qry classes at controller boundary -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-validation</artifactId>
    </dependency>
</dependencies>
```

## start/pom.xml

```xml
<dependencies>
    <dependency>
        <groupId>${project.groupId}</groupId>
        <artifactId>demo-adapter</artifactId>
        <version>${project.version}</version>
    </dependency>
    <!-- Spring Cloud infrastructure — see spring-cloud-alibaba skill for details -->
    <dependency>
        <groupId>com.alibaba.cloud</groupId>
        <artifactId>spring-cloud-starter-alibaba-nacos-discovery</artifactId>
    </dependency>
    <dependency>
        <groupId>com.alibaba.cloud</groupId>
        <artifactId>spring-cloud-starter-alibaba-nacos-config</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.cloud</groupId>
        <artifactId>spring-cloud-starter-openfeign</artifactId>
    </dependency>
</dependencies>
```

## mvnd + JDK 21 + Lombok Fix

Add to parent POM's `maven-compiler-plugin`:

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-compiler-plugin</artifactId>
    <configuration>
        <forceLegacyJavacApi>true</forceLegacyJavacApi>
    </configuration>
</plugin>
```