# Developer Kit

A modular plugin system for AI-powered development assistance, organized as installable plugins for different technology stacks.

## Available Plugins

| Plugin | Description | Skills | Agents | Commands | Rules |
|--------|-------------|--------|--------|----------|-------|
| developer-kit-java | Spring Boot + MyBatis-Plus + Spring Cloud Alibaba | 46 | 6 | 11 | 5 |

## Installation

### Quick Install (Claude Code)

```bash
# Install into current project
npx skills add your-org/developer-kit -g -y

# Or manual install via Makefile
make install
```

### Manual Install

Copy plugin components into your project's `.claude/` directory:

```bash
make install    # Install all components
make list       # List installed components
make status     # Show what's available vs installed
make uninstall  # Remove installed components
```

## Plugin Structure

Each plugin follows this structure:

```
plugins/[plugin-name]/
├── .claude-plugin/plugin.json    # Plugin manifest
├── .lsp.json                    # LSP configuration
├── README.md                    # Plugin documentation
├── agents/                      # Specialist agent definitions
├── commands/                    # Slash command definitions
├── rules/                       # Auto-activated coding rules
├── skills/                      # Reusable skill definitions
└── docs/                        # Documentation
```

## Adding New Plugins

1. Create a new directory under `plugins/`
2. Add `.claude-plugin/plugin.json` manifest
3. Add your skills, agents, commands, and rules
4. Register the plugin in `marketplace.json`

## License

MIT