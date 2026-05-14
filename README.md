# Developer Kit

Comprehensive development toolkit for Claude Code — Spring Boot / Next.js / AI Agent skills, agents, commands, and rules.

面向 Claude Code 的全栈开发工具包 — Spring Boot / Next.js / AI Agent 技能、智能体、命令与规则。

## Kits

| Kit | Description / 描述 | Skills | Agents | Commands | Rules |
|-----|---------------------|--------|--------|----------|-------|
| **java** | Spring Boot 3.5 + MyBatis-Plus + Cloud + DDD / Spring Boot 全栈 | 40 | 6 | 6 | 6 |
| **frontend** | Next.js + Tailwind v4 + React + TypeScript / 前端全栈 | 13 | 3 | 3 | 5 |
| **agent** | AI Agent / LangGraph / CrewAI / RAG / MCP / 智能体开发 | 22 | 2 | 1 | 3 |
| **base** | Language-agnostic utilities / 语言无关基础工具 | 3 | — | — | — |

> **78 skills total / 共 78 个技能**

## Tech Stack / 技术栈

| Kit | Stack |
|-----|-------|
| java | Java 21, Spring Boot 3.5.x, MyBatis-Plus, PostgreSQL 18+, Spring Cloud Alibaba (Nacos / Sentinel / RocketMQ), OpenFeign, JetCache + Redisson, Spring Security 6.x + JWT (JJWT 0.12.6), SpringDoc OpenAPI 2.8.6, JUnit 5 + Mockito + MockMvc + Testcontainers + JaCoCo |
| frontend | Next.js 15 (App Router), React 19, TypeScript 5.x, Tailwind CSS v4, React Hook Form + Zod, Zustand, Vitest + Testing Library + Playwright |
| agent | LangGraph, CrewAI, LlamaIndex, MCP (Model Context Protocol), Python 3.12+ |

## Installation / 安装

Run from your project root. Installs into `.claude/` and `.codex/` by default and safely overwrites on re-run.

从项目根目录运行，默认同时安装至 `.claude/` 和 `.codex/` 目录，重复运行会安全覆盖。

### Script Installation (Recommended) / 脚本安装（推荐）

**macOS / Linux:**
```bash
# java kit (default) / Java 工具包（默认）
bash <(curl -fsSL https://raw.githubusercontent.com/dabaicai123/developer-kit/main/install.sh)

# frontend kit / 前端工具包
bash <(curl -fsSL https://raw.githubusercontent.com/dabaicai123/developer-kit/main/install.sh) frontend

# agent kit / 智能体工具包
bash <(curl -fsSL https://raw.githubusercontent.com/dabaicai123/developer-kit/main/install.sh) agent

# base kit / 基础工具包
bash <(curl -fsSL https://raw.githubusercontent.com/dabaicai123/developer-kit/main/install.sh) base

# all kits / 全部工具包
bash <(curl -fsSL https://raw.githubusercontent.com/dabaicai123/developer-kit/main/install.sh) all

# Codex only / 仅安装到 Codex
bash <(curl -fsSL https://raw.githubusercontent.com/dabaicai123/developer-kit/main/install.sh) java codex

# Claude Code only / 仅安装到 Claude Code
bash <(curl -fsSL https://raw.githubusercontent.com/dabaicai123/developer-kit/main/install.sh) java claude
```

**Windows (PowerShell):**
```powershell
$s = irm https://raw.githubusercontent.com/dabaicai123/developer-kit/main/install.ps1

# java kit (default) / Java 工具包（默认）
& ([scriptblock]::Create($s))

# frontend kit / 前端工具包
& ([scriptblock]::Create($s)) -Kit frontend

# agent kit / 智能体工具包
& ([scriptblock]::Create($s)) -Kit agent

# base kit / 基础工具包
& ([scriptblock]::Create($s)) -Kit base

# all kits / 全部工具包
& ([scriptblock]::Create($s)) -Kit all

# Codex only / 仅安装到 Codex
& ([scriptblock]::Create($s)) -Kit java -Platform codex

# Claude Code only / 仅安装到 Claude Code
& ([scriptblock]::Create($s)) -Kit java -Platform claude
```

Codex loads project skills from `.codex/skills`; restart Codex after installing new skills.

Codex 会从 `.codex/skills` 加载项目技能；安装新技能后需要重启 Codex。

### Skills-only Installation / 仅安装技能

```bash
npx skills add dabaicai123/developer-kit -g -y
```

### Uninstall / 卸载

**macOS / Linux:**
```bash
rm -rf .claude/skills .claude/agents .claude/commands .claude/rules
rm -rf .codex/skills .codex/agents .codex/commands .codex/rules
```

**Windows (PowerShell):**
```powershell
Remove-Item -Recurse -Force .claude\skills, .claude\agents, .claude\commands, .claude\rules
Remove-Item -Recurse -Force .codex\skills, .codex\agents, .codex\commands, .codex\rules
```

---

## Java Kit / Java 工具包

### Data Access / 数据访问

| Skill | Description / 描述 |
|-------|---------------------|
| `mybatis-plus-patterns` | MyBatis-Plus mapper/entity/service patterns / MyBatis-Plus 映射器/实体/服务模式 |
| `postgresql-table-design` | PostgreSQL schema design / PostgreSQL 表结构设计 |
| `spring-boot-database-migration` | Manual SQL changeset workflow (DBA-executed) / 手动 SQL 变更集（DBA 执行） |
| `spring-boot-jetcache` | JetCache + Redisson caching & distributed services / JetCache + Redisson 缓存与分布式服务 |
| `mapstruct-patterns` | MapStruct object mapping for DDD/COLA / MapStruct DDD/COLA 层间映射 |

### Core Spring Boot / Spring Boot 核心

| Skill | Description / 描述 |
|-------|---------------------|
| `spring-boot-dependency-injection` | DI patterns and best practices / 依赖注入模式与最佳实践 |
| `spring-boot-event-driven-patterns` | Event-driven architecture patterns / 事件驱动架构模式 |
| `spring-boot-exception-handling` | Global exception handling / 全局异常处理 |
| `spring-boot-logging` | Logging configuration and patterns / 日志配置与模式 |
| `spring-boot-rest-api-standards` | REST API design standards / REST API 设计标准 |
| `spring-boot-rest-client` | RestClient configuration, timeout, OAuth2 / RestClient 配置、超时与 OAuth2 |
| `spring-boot-validation` | Input validation patterns / 输入校验模式 |
| `spring-boot-transaction-management` | Transaction propagation, rollback, Saga/Outbox / 事务传播、回滚与 Saga/Outbox 模式 |
| `spring-boot-configuration-management` | @ConfigurationProperties, Nacos Config, profiles / 配置属性、Nacos 配置中心与多环境 |
| `spring-boot-async-processing` | @Async, CompletableFuture, ThreadPoolTaskExecutor / 异步处理与线程池 |
| `spring-boot-scheduled-tasks` | @Scheduled, XXL-Job distributed scheduling / 定时任务与分布式调度 |
| `spring-boot-file-handling` | File upload/download, MinIO/OSS, EasyExcel / 文件上传下载与 MinIO/OSS |
| `spring-boot-amqp` | RabbitMQ: Jackson converter, producer/consumer, DLX / RabbitMQ 生产者消费者与死信 |
| `spring-boot-openapi-documentation` | SpringDoc 2.8.x + OpenAPI 3.0 for DDD/COLA / SpringDoc + OpenAPI DDD 项目文档 |
| `spring-boot-jackson-config` | Jackson ObjectMapper config: JavaTimeModule, serialization / Jackson 序列化配置 |

### Security / 安全

| Skill | Description / 描述 |
|-------|---------------------|
| `spring-boot-security` | Spring Security configuration / Spring Security 配置 |
| `spring-boot-security-jwt` | JWT authentication with JJWT / JWT 认证与 JJWT |

### Microservices & Cloud / 微服务与云

| Skill | Description / 描述 |
|-------|---------------------|
| `spring-cloud-alibaba` | Spring Cloud Alibaba (Nacos, Sentinel, RocketMQ) / Spring Cloud Alibaba 全栈 |
| `spring-cloud-gateway` | Spring Cloud Gateway patterns / 网关模式 |
| `spring-cloud-openfeign` | OpenFeign client patterns / OpenFeign 客户端模式 |
| `spring-kafka` | Spring Kafka patterns / Spring Kafka 模式 |

### Resilience & Monitoring / 弹性与监控

| Skill | Description / 描述 |
|-------|---------------------|
| `spring-boot-actuator` | Actuator endpoints and monitoring / Actuator 监控端点 |
| `spring-boot-load-testing` | k6 load testing / k6 负载测试 |
| `spring-boot-resilience4j` | Resilience4j patterns / Resilience4j 容错模式 |

### Testing (6) / 测试（6 项）

| Skill | Description / 描述 |
|-------|---------------------|
| `spring-boot-slice-testing` | Spring Context slice tests (Events, Scheduled, ConfigProps, @JsonTest, Caching) / Spring 分层测试 |
| `unit-test-techniques` | General JUnit 5 techniques: parameterized, boundary, utility / 通用 JUnit 5 测试技巧 |
| `unit-test-security-authorization` | Security authorization testing / 安全授权测试 |
| `unit-test-wiremock-rest-api` | WireMock REST API testing / WireMock REST API 测试 |
| `spring-boot-tdd` | TDD workflow / TDD 工作流 |
| `spring-boot-verification` | Verification patterns (build + test + security) / 验证模式（构建+测试+安全） |

### Architecture & DevOps / 架构与运维

| Skill | Description / 描述 |
|-------|---------------------|
| `ddd-cola` | COLA DDD architecture + scaffolding / COLA DDD 架构与项目脚手架 |
| `ddd-event-driven` | Event-driven DDD patterns / 事件驱动 DDD 模式 |
| `docker-expert` | Docker patterns / Docker 模式 |
| `graalvm-native-image` | GraalVM Native Image builds / GraalVM Native Image 构建 |
| `architecture-decision-records` | ADR drafting / 架构决策记录 |

### Java Agents / Java 智能体

| Agent | Description / 描述 |
|-------|---------------------|
| `devkit:java:feature` | Spring Boot feature implementation / Spring Boot 功能实现 |
| `devkit:java:review` | Code quality review / 代码质量审查 |
| `devkit:java:test` | Testing strategy / 测试策略 |
| `devkit:java:refactor` | Refactoring patterns / 重构模式 |
| `devkit:java:security` | Security audit / 安全审计 |
| `devkit:java:db` | PostgreSQL specialist / PostgreSQL 专家 |

### Java Commands / Java 命令

| Command | Description / 描述 |
|---------|---------------------|
| `/devkit.feature` | Implement a Spring Boot feature / 实现 Spring Boot 功能 |
| `/devkit.review` | Review code for quality, security, architecture / 审查代码质量与安全 |
| `/devkit.test` | Generate unit or integration tests / 生成单元/集成测试 |
| `/devkit.refactor` | Refactor a class or module / 重构类或模块 |
| `/devkit.security` | Security audit / 安全审计 |
| `/devkit.db` | PostgreSQL design & optimization / PostgreSQL 设计与优化 |

### Java Rules / Java 规则

| Rule | Applies to / 作用于 |
|------|----------------------|
| `naming-conventions` | `**/*.java` / 命名规范 |
| `project-structure` | `**/*.java` / 项目结构 |
| `error-handling` | `**/*.java` / 错误处理 |
| `java-coding-style` | `**/*.java` / Java 编码风格 |
| `mybatis-plus-conventions` | `**/*Mapper.java`, `**/*Service.java` / MyBatis-Plus 约定 |
| `transaction-conventions` | `**/*Service.java` / 事务约定 |

---

## Frontend Kit / 前端工具包

### Frontend Skills / 前端技能

| Skill | Description / 描述 |
|-------|---------------------|
| `nextjs-app-router` | Next.js 15 App Router (RSC, routes, metadata) / Next.js App Router 全栈 |
| `typescript-react` | TypeScript + React patterns (hooks, types, components) / TS+React 类型与模式 |
| `tailwind-v4` | Tailwind CSS v4 (theme, variants, migration from v3) / Tailwind v4 主题与迁移 |
| `react-best-practices` | Performance, rendering, bundle optimization / React 性能与渲染优化 |
| `react-composition` | Compound components, state lifting, API design / React 组合模式 |
| `state-management` | Zustand, URL state, decision guide / 状态管理决策与 Zustand |
| `data-fetching` | Server/client fetching, typed API, pagination / 数据获取与分页模式 |
| `forms-and-validation` | React Hook Form + Zod, server actions / 表单校验与 Server Actions |
| `frontend-testing` | Vitest, Testing Library, Playwright E2E / 前端测试全栈 |
| `frontend-debugging` | Type errors, hydration, effect bugs / 前端调试技巧 |
| `frontend-code-review` | Review heuristics, anti-pattern fixes / 前端代码审查 |
| `design-to-code` | Design spec → React component (Figma, screenshots) / 设计稿转组件 |
| `web-design-audit` | Visual design quality audit / Web 视觉设计审计 |

### Frontend Agents / 前端智能体

| Agent | Description / 描述 |
|-------|---------------------|
| `devkit:frontend:design-to-react` | Design-to-React conversion / 设计稿转 React 组件 |
| `devkit:frontend:reviewer` | Frontend code review / 前端代码审查 |
| `devkit:frontend:test` | Frontend testing / 前端测试 |

### Frontend Commands / 前端命令

| Command | Description / 描述 |
|---------|---------------------|
| `/devkit.frontend-feature` | Implement a frontend feature / 实现前端功能 |
| `/devkit.design-to-component` | Design spec → React component / 设计稿转组件 |
| `/devkit.frontend-review` | Review frontend code / 审查前端代码 |

### Frontend Rules / 前端规则

| Rule | Applies to / 作用于 |
|------|----------------------|
| `react-conventions` | React component patterns / React 组件约定 |
| `nextjs-conventions` | Next.js patterns / Next.js 约定 |
| `tailwind-conventions` | Tailwind usage / Tailwind 使用约定 |
| `typescript-react-conventions` | TypeScript + React types / TS+React 类型约定 |
| `common-coding-style` | General style / 通用编码风格 |

---

## Agent Kit / 智能体工具包

### Core Agent Patterns / 智能体核心模式

| Skill | Description / 描述 |
|-------|---------------------|
| `agent-loop-patterns` | Agent loop design (ReAct, Plan-and-Execute) / 智能体循环模式 |
| `agent-tool-design` | Tool/function design patterns / 工具/函数设计模式 |
| `agent-prompt-engineering` | Prompt templates, system prompts / 提示词工程 |
| `agent-context-management` | Context window, summarization, token budgets / 上下文管理与压缩 |
| `agent-memory-systems` | Short-term/long-term memory, episodic / 智能体记忆系统 |
| `agent-planning-reasoning` | Tree of Thought, MCTS, HTN, constraint satisfaction / 智能体规划与推理模式 |
| `agent-human-interaction` | Human-in-the-loop, escalation, clarification dialogs / 智能体人机交互模式 |
| `agent-error-recovery` | Circuit breakers, retry, self-healing, fallback / 智能体容错与恢复模式 |

### Observability & Operations / 可观测性与运营

| Skill | Description / 描述 |
|-------|---------------------|
| `agent-observability` | Logging, tracing, cost tracking / 智能体可观测性 |
| `agent-evaluation` | Benchmarks, scoring, regression testing / 智能体评估 |
| `agent-cost-optimization` | Token budgeting, model routing, LLM caching / 智能体成本优化 |

### Safety & Quality / 安全与质量

| Skill | Description / 描述 |
|-------|---------------------|
| `agent-guardrails` | Safety, validation, output filtering / 智能体安全护栏 |
| `agent-streaming-realtime` | SSE/WebSocket streaming, progressive delivery / 智能体流式与实时模式 |
| `agent-testing-debugging` | Unit/integration testing, trajectory replay, mock LLMs / 智能体测试与调试 |

### Multi-Agent & Frameworks / 多智能体与框架

| Skill | Description / 描述 |
|-------|---------------------|
| `multi-agent-orchestration` | Multi-agent coordination, routing / 多智能体编排 |
| `langgraph-patterns` | LangGraph state graphs, branching, persistence / LangGraph 状态图模式 |
| `crewai-patterns` | CrewAI crew/process/task patterns / CrewAI 多角色协作模式 |
| `crewai-project-architecture` | CrewAI project scaffolding, YAML-first definitions / CrewAI 项目架构 |
| `llamaindex-rag-patterns` | LlamaIndex RAG pipelines, chunking, retrieval / LlamaIndex RAG 管线模式 |
| `mcp-integration` | MCP server design, tool registration / MCP 集成与工具注册 |
| `openai-agents-pydantic-ai` | OpenAI Agents SDK & PydanticAI patterns / OpenAI Agents 与 PydanticAI 模式 |
| `agent-project-architecture` | General agent project scaffolding / 智能体项目架构 |

### Agent Agents / 智能体专用智能体

| Agent | Description / 描述 |
|-------|---------------------|
| `devkit:agent:crewai` | CrewAI system builder / CrewAI 系统构建专家 |
| `devkit:agent:rag` | RAG pipeline builder / RAG 管线构建专家 |

### Agent Command / 智能体命令

| Command | Description / 描述 |
|---------|---------------------|
| `/devkit.agent` | Scaffold, build, or evaluate an AI agent / 构建、评估 AI 智能体 |

### Agent Rules / 智能体规则

| Rule | Applies to / 作用于 |
|------|----------------------|
| `agent-project-structure` | `**/*.py` / 智能体项目结构 |
| `agent-naming-conventions` | `**/*.py` / 智能体命名约定 |
| `agent-safety-conventions` | `**/*.py` / 智能体安全约定 |

---

## Base Kit / 基础工具包

| Skill | Description / 描述 |
|-------|---------------------|
| `create-readme` | Generate comprehensive README files / 生成项目 README |
| `documentation-writer` | Write technical documentation / 编写技术文档 |
| `git-commit` | Generate well-structured commit messages / 生成规范的 Git 提交信息 |

---

## Quick Start / 快速上手

1. Install the kit that matches your project / 安装与项目对应的工具包
2. Skills auto-trigger when Claude Code detects relevant context / 技能在 Claude Code 检测到相关上下文时自动触发
3. Use slash commands for intentional workflows / 使用斜杠命令执行有意的工作流

```bash
# Example: implement a Spring Boot feature / 示例：实现 Spring Boot 功能
/devkit.feature Add user registration endpoint with JWT auth

# Example: review frontend code / 示例：审查前端代码
/devkit.frontend-review src/components/UserProfile.tsx

# Example: build an AI agent / 示例：构建 AI 智能体
/devkit.agent Build a RAG pipeline for document Q&A using LlamaIndex
```

## Contributing / 贡献

PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

欢迎提交 PR，参见贡献指南。

## License / 许可证

MIT License.
