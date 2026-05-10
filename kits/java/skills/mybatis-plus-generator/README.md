# MyBatis-Plus Generator Skill

Code generation skill for MyBatis-Plus: scaffolding CRUD code from database tables with MVC and DDD/COLA architecture support.

**Trigger**: Only when user explicitly mentions **MyBatis-Plus** or **mybatis-plus-generator**.

## Features

- FastAutoGenerator builder API (3.5.3+)
- MVC and DDD/COLA architecture support
- Java and Kotlin language support
- Custom artifact generation via `CustomFile.Builder` (DTO/VO/BO/Cmd/Converter)
- OpenAPI 3 annotations support
- IFileCreate protection for existing custom code

## Directory Structure

```
mybatis-plus-generator/
├── SKILL.md                              # Skill definition (Agent Skills spec)
├── LICENSE.txt                           # Apache 2.0
├── README.md                             # This file
├── examples/
│   └── ddd-architecture-example.md      # COLA architecture generation example
├── references/
│   ├── mybatis-plus-generator-guide.md  # FastAutoGenerator configuration guide
│   ├── template-variables.md            # FreeMarker template variables
│   ├── code-generation-standards.md     # Comment standards and code quality
│   ├── progress-and-statistics-formats.md # Progress update format
│   └── swagger-annotations-guide.md     # OpenAPI 3 annotations
└── templates/                            # FreeMarker code templates (.ftl)
    ├── entity.java.ftl / entity.kt.ftl
    ├── mapper.java.ftl / mapper.kt.ftl
    ├── service.java.ftl / service.kt.ftl
    ├── serviceImpl.java.ftl / serviceImpl.kt.ftl
    ├── controller.java.ftl / controller.kt.ftl
    ├── dto.java.ftl / dto.kt.ftl
    ├── vo.java.ftl / vo.kt.ftl
    ├── bo.java.ftl / bo.kt.ftl
    ├── aggregate-root.java.ftl / aggregate-root.kt.ftl
    ├── repository.java.ftl / repository.kt.ftl
    ├── domain-service.java.ftl / domain-service.kt.ftl
    ├── value-object.java.ftl / value-object.kt.ftl
    ├── domain-event.java.ftl / domain-event.kt.ftl
    ├── application-service.java.ftl / application-service.kt.ftl
    └── assembler.java.ftl / assembler.kt.ftl
```

## Architecture Support

### MVC Architecture

Standard MVC: Entity, Mapper, Service/ServiceImpl, Controller, DTO/VO/BO.

### DDD/COLA Architecture

COLA V5: Domain Entity (bare name), DO (suffix), Gateway (port), GatewayImpl, Cmd, CmdExe/QryExe, ServiceI, Converter (MapStruct). See `ddd-cola` skill for full layer structure.

> Template file names use generic DDD terms (repository, assembler) but map to COLA naming (Gateway, Converter) when generating COLA architecture code.

## References

- `references/mybatis-plus-generator-guide.md` — FastAutoGenerator usage guide
- `references/template-variables.md` — FreeMarker template variables
- `references/code-generation-standards.md` — Comment standards and code quality
- `references/swagger-annotations-guide.md` — OpenAPI 3 annotations
- `references/progress-and-statistics-formats.md` — Progress update format

## Related Skills

- `ddd-cola` — COLA architecture layer structure
- `mybatis-plus-patterns` — coding patterns for manually writing MyBatis-Plus modules
- `mapstruct-patterns` — Converter patterns for Domain ↔ DO/DTO

## License

Apache 2.0 — See `LICENSE.txt`