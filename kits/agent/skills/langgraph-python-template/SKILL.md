---
name: langgraph-python-template
description: "Scaffolds Python LangGraph agent projects from official LangGraph templates, including new-langgraph-project-python and react-agent starters. Use when creating a LangGraph app, graph agent scaffold, Python agent template, or LangGraph starter project."
version: "1.0.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# LangGraph Python Template

Use this skill to create a new Python LangGraph project from official LangGraph templates. It owns project generation and first-run verification, not graph design details.

## Scope Boundary

- Use `langgraph-python-template` for new Python LangGraph project scaffolds.
- Use `langgraph-persistence` for persistence, memory, checkpoints, and interrupts.
- Use `agent-testing-debugging` and `agent-evaluation` for test and eval expansion.

## Template Choice

| Need | Starter |
|---|---|
| Minimal LangGraph app with current official layout | `new-langgraph-project-python` |
| Tool-using ReAct agent starter | Official `langchain-ai/react-agent` template |
| Existing codebase adoption | Add LangGraph files surgically instead of replacing the project |

## Scaffold Workflow

1. Confirm the target directory name and whether the user wants a minimal graph app or ReAct agent starter.
2. Install or run the current LangGraph CLI with the user's Python package manager.
3. Generate the project with the official template:

```bash
uv tool install langgraph-cli
langgraph new path/to/app --template new-langgraph-project-python
```

4. For the ReAct starter, use the official `langchain-ai/react-agent` GitHub template or the current LangGraph CLI template if it exposes that option.
5. Inspect generated `pyproject.toml`, `langgraph.json`, `.env.example`, `src/`, and `tests/` before adding custom code.
6. Keep generated layout intact unless a user requirement conflicts with it.

## Required Adjustments

- Add project-specific environment variables to `.env.example`, never real secrets.
- Keep graph construction, prompts, tools, and configuration in separate modules when the scaffold exposes those boundaries.
- Add or preserve tests that can run without external model calls.
- Document the local run command and any LangGraph server command used for manual verification.

## Verification

Run the checks supported by the generated project, usually:

```bash
uv sync
uv run pytest
```

If the project is intended for local LangGraph development, also verify the graph loads with the current LangGraph CLI command documented by the generated scaffold.

## Official References

- LangGraph deployment quickstart: `https://docs.langchain.com/langsmith/deployment-quickstart`
- Minimal Python template: `https://github.com/langchain-ai/new-langgraph-project`
- ReAct agent template: `https://github.com/langchain-ai/react-agent`

## Output Checklist

- Official template source is named.
- Target path and selected starter are stated.
- Generated files are inspected before customization.
- `.env.example` contains placeholders only.
- Tests or a graph-load check verify the scaffold.

## Anti-Patterns

- Hand-writing a LangGraph project from memory when the official template fits.
- Replacing an existing app's packaging or test layout without a migration reason.
- Pinning old LangGraph imports or CLI flags without checking current docs.
- Committing `.env`, generated caches, or local LangGraph runtime artifacts.
