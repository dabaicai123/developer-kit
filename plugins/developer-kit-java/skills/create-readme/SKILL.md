---
name: create-readme
description: Creates comprehensive README files with proper structure, badges, and installation instructions. Use when creating project README, writing documentation, or setting up project documentation.
version: "1.0.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Create README

Generate comprehensive README files.

## When to use this skill

- Creating a new project README or updating an existing one
- Writing documentation for project setup, features, and configuration
- Generating standard README structure with badges, installation, and usage sections

## Structure

```markdown
# Project Name

[![Build Status](badge)](link)

Brief description.

## Features

- Feature 1
- Feature 2

## Requirements

- Java 21+
- Maven 3.9+

## Installation

\`\`\`bash
git clone https://github.com/user/repo.git
cd repo
mvn install
\`\`\`

## Quick Start

\`\`\`bash
mvn spring-boot:run
\`\`\`

## Usage

\`\`\`java
// Example code
\`\`\`

## Configuration

| Property | Description | Default |
|----------|-------------|---------|
| app.name | Name | my-app |

## API Reference

See [API Docs](docs/api.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT License.
```

## Best Practices

- Keep description brief
- Include status badges
- Clear installation steps
- Usage examples
- Document configuration
- Link to additional docs
- Contribution guidelines
- License information
