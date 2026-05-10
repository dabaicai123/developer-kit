# Module pom.xml Templates

Full pom.xml templates for each module. Only dependency declarations — no plugins, no exclusions. Plugin configuration belongs in the parent POM.

## parent/pom.xml

```xml
<properties>
    <java.version>21</java.version>
    <spring-boot.version>3.5.1</spring-boot.version>
    <spring-cloud-alibaba.version>2025.0.0.0</spring-cloud-alibaba.version>
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
</dependencies>
```

> OpenFeign is `provided` scope — client module only needs the annotation for compilation. Other services bring the Feign runtime themselves.
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