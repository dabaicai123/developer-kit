# Template Variables Reference

FreeMarker template variables available in MyBatis-Plus Generator templates (`.ftl` files).

## Package Variables

- `${package.Entity}` — Entity package path (e.g., `com.example.app.domain.model.entity`)
- `${package.Mapper}` — Mapper package path (e.g., `com.example.app.infrastructure.mapper`)
- `${package.Service}` — Service package path
- `${package.ServiceImpl}` — ServiceImpl package path
- `${package.Controller}` — Controller package path (e.g., `com.example.app.adapter.controller`)
- `${package.ModuleName}` — Module name (optional)

## Class Name Variables

- `${entity}` — Entity class name (e.g., `User`)
- `${table.entityName}` — Entity class name (same as `${entity}`)
- `${table.mapperName}` — Mapper interface name (e.g., `UserMapper`)
- `${table.serviceName}` — Service interface name (e.g., `UserService`)
- `${table.serviceImplName}` — ServiceImpl class name (e.g., `UserServiceImpl`)
- `${table.controllerName}` — Controller class name (e.g., `UserController`)
- `${table.entityPath}` — Entity path for URL (e.g., `user`)

## Table Variables

- `${table.name}` — Table name (e.g., `user`)
- `${table.comment}` — Table comment from database metadata
- `${schemaName}` — Database schema name (optional)

## Author and Date

- `${author}` — Author name
- `${date}` — Current date (yyyy-MM-dd format)

## Field Variables (iterate with `<#list table.fields as field>`)

- `${field.name}` — Database column name (e.g., `user_name`)
- `${field.propertyName}` — Java property name (e.g., `userName`)
- `${field.propertyType}` — Java property type (e.g., `String`)
- `${field.comment}` — Field comment from database
- `${field.keyFlag}` — Whether primary key (boolean)
- `${field.fill}` — Field fill strategy (INSERT, UPDATE, INSERT_UPDATE)
- `${field.versionField}` — Whether version field (boolean)
- `${field.logicDeleteField}` — Whether logical delete field (boolean)

## Configuration Variables

- `${cfg.enableSwagger}` — Whether API documentation enabled (from customMap)
- `${entityLombokModel}` — Whether Lombok enabled (boolean)
- `${restControllerStyle}` — Whether REST style (boolean)

## FreeMarker Syntax

### Conditionals

```ftl
<#if cfg.enableSwagger>
@Schema(description = "${field.comment}")
</#if>
```

### Loops

```ftl
<#list table.fields as field>
    private ${field.propertyType} ${field.propertyName};
</#list>
```

### Custom Map Access

```ftl
<#if cfg.enableSwagger>
@Tag(name = "${table.comment} Management")
</#if>
```

## References

- [MyBatis-Plus Generator Documentation](https://baomidou.com/pages/d357af/)
- [FreeMarker Template Syntax](https://freemarker.apache.org/docs/dgui_template.html)