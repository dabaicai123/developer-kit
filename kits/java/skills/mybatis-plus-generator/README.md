# MyBatis-Plus Generator Skill

Code generation skill for MyBatis-Plus: scaffolding CRUD code from database tables with MVC and DDD/COLA architecture support.

**Trigger**: Only when user explicitly mentions **MyBatis-Plus** or **mybatis-plus-generator**.

## Features

- FastAutoGenerator builder API (3.5.3+)
- MVC and DDD/COLA architecture support
- Custom artifact generation via `CustomFile.Builder` (DTO/VO/BO/Cmd/Converter)
- IFileCreate protection for existing custom code

## Directory Structure

```
mybatis-plus-generator/
├── SKILL.md                              # Skill definition
├── references/
│   ├── architecture-directory-quick-reference.md  # Directory mapping for all architectures
│   ├── template-variables.md            # FreeMarker template variables
│   └── code-generation-standards.md     # Comment standards and code quality
├── examples/
│   ├── ddd-architecture-example.md      # COLA architecture generation example
│   └── mvc-architecture-example.md      # MVC architecture generation example
└── templates/                            # FreeMarker code templates (.ftl)
```

## Architecture Support

- **MVC**: Entity, Mapper, Service/ServiceImpl, Controller, DTO/VO/BO
- **COLA V5**: Domain Entity (bare name), DO (suffix), Gateway, GatewayImpl, Cmd, CmdExe/QryExe, ServiceI, Converter (MapStruct). See `ddd-cola` skill for full layer structure.

## References

- `references/architecture-directory-quick-reference.md` — Directory mapping for MVC, DDD, Hexagonal, Clean, COLA architectures
- `references/template-variables.md` — FreeMarker template variables
- `references/code-generation-standards.md` — Comment standards and code quality

## Related Skills

- `ddd-cola` — COLA architecture layer structure
- `mybatis-plus-patterns` — coding patterns for manually writing MyBatis-Plus modules
- `mapstruct-patterns` — Converter patterns for Domain <-> DO/DTO
- `spring-boot-openapi-documentation` — OpenAPI 3 annotations for generated controllers