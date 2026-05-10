# MyBatis-Plus Generator Reference Guide

## FastAutoGenerator Builder API (3.5.3+)

The recommended API uses builder pattern with `FastAutoGenerator`. Legacy `AutoGenerator` with setter pattern is deprecated.

### Core Components

1. **FastAutoGenerator** — Builder-based entry point. Chains globalConfig, packageConfig, strategyConfig, injectionConfig, and templateEngine.
2. **Template Engine** — FreeMarker (recommended), Velocity, or Beetl. This skill uses FreeMarker exclusively.
3. **CustomFile.Builder** — Generates custom artifacts (DTO, VO, BO, Cmd, Converter) beyond the 6 standard types.

### Generation Flow

```
Database table structure
    → Read table metadata (columns, types, constraints)
    → Apply configuration strategies (naming, package paths, etc.)
    → Load FreeMarker template files (.ftl)
    → Replace template variables
    → Generate code files
```

## Configuration Sections

### GlobalConfig

```java
FastAutoGenerator.create(url, username, password)
    .globalConfig(builder -> builder
        .author("AuthorName")
        .outputDir(projectPath + "/src/main/java")
        .disableOpenDir()
    )
```

### PackageConfig (COLA mapping example)

```java
.packageConfig(builder -> builder
    .parent("com.example")
    .moduleName("app")
    .entity("infrastructure.mapper.dataobject")  // DO classes
    .mapper("infrastructure.mapper")
    .service("app.service")
    .serviceImpl("app.service.impl")
    .controller("adapter.controller")
)
```

### StrategyConfig

```java
.strategyConfig(builder -> builder
    .addInclude("user", "order")
    .addTablePrefix("tbl_")
    .entityBuilder()
        .enableLombok()
        .enableTableFieldAnnotation()
        .idType(IdType.ASSIGN_ID)
        .logicDeleteColumnName("deleted_at")
        .versionColumnName("version")
    .controllerBuilder()
        .enableRestStyle()
        .enableHyphenStyle()
    .serviceBuilder()
        .formatServiceFileName("%sService")
        .formatServiceImplFileName("%sServiceImpl")
)
```

### InjectionConfig (Custom Artifacts)

```java
.injectionConfig(builder -> {
    Map<String, Object> customMap = new HashMap<>();
    customMap.put("enableSwagger", true);
    builder.customMap(customMap);

    // Generate DTO via custom template
    builder.customFile(new CustomFile.Builder()
        .fileName("UserDTO.java")
        .templatePath("templates/entityDTO.java.ftl")
        .packageName("adapter.dto")
        .build());
})
```

## Best Practices

- Run generator once for initial scaffolding, then manually customize — never re-run on modified files
- Use `IFileCreate` to protect existing files if re-running is necessary
- Use FreeMarker templates (`.ftl`) — not Velocity (`.vm`)
- Use OpenAPI 3 annotations in custom templates
- For COLA architecture: use `CustomFile.Builder` to generate Gateway, CmdExe, Converter, etc. into their respective layer packages

## References

- [MyBatis-Plus Generator Documentation](https://baomidou.com/pages/d357af/)
- [MyBatis-Plus GitHub](https://github.com/baomidou/mybatis-plus)