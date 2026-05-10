# Progress Updates and Statistics Formats

## Progress Update Format

```markdown
## Code Generation Progress

### {tableName}

- [x] {ClassName}.java — {type} ({details})
- [ ] {ClassName}.java — {type}
```

Update progress after each file is generated. Mark table complete when all its files are done.

## Statistics Format

```markdown
## Code Generation Statistics

- **Tables**: {count} ({names})
- **Objects**: {count} total ({type breakdown})
- **Files**: {count} total
```

### Per-Table Breakdown

```markdown
### {tableName}
- DO: 1 ({fieldCount} fields)
- Mapper: 1 (extends BaseMapper)
- Gateway + GatewayImpl: 2
- CmdExe + QryExe: 2
- Controller: 1 ({endpointCount} endpoints)
- DTO/VO/Cmd: {count}
- Converter: {count}
```