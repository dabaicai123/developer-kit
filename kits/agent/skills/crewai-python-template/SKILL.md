---
name: crewai-python-template
description: "Scaffolds Python CrewAI projects with the official CrewAI CLI for crews and flows, including starter layout, config, run commands, and verification. Use when creating a CrewAI project, crew scaffold, flow scaffold, or Python multi-agent starter."
version: "1.0.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# CrewAI Python Template

Use this skill to create a new Python CrewAI project from the official CrewAI CLI. It owns project generation and first-run verification, not CrewAI role, task, or Flow design details.

## Scope Boundary

- Use `crewai-python-template` for new CrewAI project scaffolds.
- Keep this skill focused on official CLI generation and first-run verification.
- Use `multi-agent-orchestration` only when multiple agents have a concrete coordination benefit.

## Template Choice

| Need | Command |
|---|---|
| Role-based task execution starter | `crewai create crew <project-name>` |
| Stateful event-driven workflow starter | `crewai create flow <project-name>` |
| Production workflow with specialist execution | Start with a Flow, then call a Crew from a Flow step |

## Scaffold Workflow

1. Confirm the project name and choose `crew`, `flow`, or Flow plus Crew.
2. Install or run the current CrewAI CLI with the user's Python package manager.
3. Generate the project with the official CLI:

```bash
crewai create crew my_agent_project
```

or:

```bash
crewai create flow my_agent_project
```

4. Inspect generated `pyproject.toml`, `src/`, config files, `.env` or `.env.example`, and tests before adding custom code.
5. Keep generated CrewAI config and Python orchestration separated unless the current scaffold uses a different official convention.

## Required Adjustments

- Replace generated sample roles, tasks, and Flow events only with user-requested behavior.
- Move real secrets out of committed files and keep only placeholders in examples.
- Keep tool credentials and model routes in environment/config, not agent YAML.
- Add focused tests or eval cases around custom tools, task outputs, and Flow routing.

## Verification

Run the checks supported by the generated project. Typical commands include:

```bash
crewai install
crewai run
```

If tests are present or added, run the project's Python test command as well.

## Official References

- CrewAI CLI docs: `https://docs.crewai.com/en/concepts/cli`
- CrewAI quickstart: `https://docs.crewai.com/en/quickstart`

## Output Checklist

- CrewAI CLI command and project type are stated.
- Generated project layout is inspected before customization.
- Crew vs Flow choice is justified.
- Secrets are placeholders only.
- A run command, test, or documented manual check verifies the scaffold.

## Anti-Patterns

- Hand-writing a CrewAI starter while the official CLI fits the target.
- Using a Crew alone for stateful production orchestration.
- Embedding credentials, model routes, or policy decisions in agent YAML.
- Adding extra agents before their roles, tools, and outputs are clearly distinct.
