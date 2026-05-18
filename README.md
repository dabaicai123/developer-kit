# Developer Kit

Comprehensive development toolkit for Claude Code — Spring Boot / Next.js / AI Agent skills, agents, commands, and rules.

面向 Claude Code 的全栈开发工具包 — Spring Boot / Next.js / AI Agent 技能、智能体、命令与规则。

## Kits

| Kit | Description / 描述 | Skills | Agents | Commands | Rules |
|-----|---------------------|--------|--------|----------|-------|
| **java** | Spring Boot 3.5 + MyBatis-Plus + Cloud + DDD / Spring Boot 全栈 | 39 | 6 | 6 | 6 |
| **frontend** | Next.js + Supabase + TanStack Query frontend workflow / 前端迁移、接口对接与多应用代理 | 6 | 3 | 3 | 5 |
| **agent** | AI Agent / LangGraph / CrewAI / RAG / MCP / 智能体开发 | 14 | 2 | 1 | 0 |
| **base** | Language-agnostic utilities / 语言无关基础工具 | 4 | — | — | 1 |

> **63 skills total / 共 63 个技能**

## Tech Stack / 技术栈

| Kit | Stack |
|-----|-------|
| java | Java 21, Spring Boot 3.5.x, MyBatis-Plus, PostgreSQL 18+, Spring Cloud Alibaba (Nacos / Sentinel / RocketMQ), OpenFeign, JetCache + Redisson, Spring Security 6.x + JWT (JJWT 0.12.6), SpringDoc OpenAPI 2.8.6, JUnit 5 + Mockito + MockMvc + Testcontainers + JaCoCo |
| frontend | Next.js 15 (App Router), React 19, Supabase, TanStack Query, TypeScript, HTML/CSS migration, API contracts, multi-app reverse proxy, frontend quality gates |
| agent | LangGraph, CrewAI, LlamaIndex, MCP (Model Context Protocol), Python 3.12+ |

## Installation / 安装

Run from your project root. Installs into `.claude/` and `.codex/` by default. Re-running merges the selected kit into the existing installation and overwrites matching files from that kit.

从项目根目录运行，默认同时安装至 `.claude/` 和 `.codex/` 目录。重复运行会把本次选择的 kit 合并到现有安装中，并覆盖该 kit 的同名文件。

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
Make sure skills are enabled in `~/.codex/config.toml`:

```toml
[features]
skills = true
```

Claude agents are converted to Codex subagents in `.codex/agents/*.toml`, using Codex-friendly names such as `devkit_java_feature`. The installer also creates `.codex/config.toml` with an `[agents]` section when it is missing.

Codex 会从 `.codex/skills` 加载项目技能；安装新技能后需要重启 Codex。

Codex 自定义智能体会安装为 `.codex/agents/*.toml`；Claude 的 agent markdown 会在安装到 Codex 时自动转换。

Platform-specific installers live in `claude/` and `codex/`; root install scripts only select kits, clone or locate the repo, and dispatch to the platform installer.

平台差异安装逻辑分别放在 `claude/` 与 `codex/` 目录；根安装脚本只负责选择 kit、定位仓库并分发到对应平台安装器。

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
| `html-css-nextjs-migration` | Native HTML/CSS temp/ migration to reusable Next.js design system / 原生 HTML/CSS 迁移为 Next.js 组件体系 |
| `nextjs-supabase-template` | Latest official Next.js with-supabase starter workflow / Next.js + Supabase 认证项目模板 |
| `nextjs-multi-app-proxy-template` | Main web gateway with independent child app reverse proxy / 主 Web 统一入口与独立子工程反向代理模板 |
| `tanstack-query` | TanStack Query v5 API integration, cache, mutations, infinite queries / TanStack Query 后端接口对接与缓存 |
| `frontend-api-contracts` | OpenAPI, typed clients, validation, errors, env, mocks / 前端 API 合同与后端接口约定 |
| `frontend-quality-gates` | Build, visual, responsive, accessibility, API-state checks / 前端交付质量门禁 |

### Frontend Agents / 前端智能体

| Agent | Description / 描述 |
|-------|---------------------|
| `devkit:frontend:migration` | HTML/CSS migration to Next.js / 原生前端迁移 |
| `devkit:frontend:api` | Backend API integration / 后端接口对接 |
| `devkit:frontend:quality` | Frontend quality verification / 前端质量验证 |

### Frontend Commands / 前端命令

| Command | Description / 描述 |
|---------|---------------------|
| `/devkit.frontend-migrate` | Migrate temp/ HTML/CSS into Next.js / 迁移原生 HTML/CSS |
| `/devkit.frontend-api` | Integrate backend APIs with TanStack Query / 对接后端接口 |
| `/devkit.frontend-verify` | Run frontend quality gates / 执行前端质量门禁 |

### Frontend Rules / 前端规则

| Rule | Applies to / 作用于 |
|------|----------------------|
| `html-css-migration-conventions` | HTML/CSS migration and design system reuse / 原生前端迁移约定 |
| `nextjs-supabase-conventions` | Supabase auth/session boundaries / Supabase 认证边界 |
| `tanstack-query-conventions` | TanStack Query server-state rules / TanStack Query 服务端状态约定 |
| `api-contract-conventions` | API contracts, errors, env, validation / API 合同约定 |
| `frontend-quality-gates` | Build, visual, responsive, accessibility checks / 前端质量门禁 |

---

## Agent Kit / 智能体工具包

### Agent Skills / 智能体技能

| Skill | Description / 描述 |
|-------|---------------------|
| `agent-context-engineering` | Context engineering and multi-agent architecture patterns / 上下文工程与多智能体架构 |
| `agent-prompt-engineering` | Prompt optimization frameworks and templates / 提示词优化框架与模板 |
| `agentic-eval` | Agent evaluation workflows and quality checks / 智能体评估工作流 |
| `crewai-python-template` | Official CrewAI crew and flow scaffolding / CrewAI 项目脚手架 |
| `design-agent` | CrewAI agent role, goal, tools, and runtime configuration / CrewAI Agent 设计 |
| `design-task` | CrewAI task dependencies, outputs, guardrails, and execution / CrewAI Task 设计 |
| `eval-driven-dev` | Eval-driven development loop for agent systems / 智能体评估驱动开发 |
| `getting-started` | CrewAI architecture decisions and starter flows / CrewAI 入门与架构选择 |
| `langgraph-fundamentals` | LangGraph StateGraph, nodes, edges, and commands / LangGraph 基础 |
| `langgraph-human-in-the-loop` | LangGraph interrupt, approval, and resume patterns / LangGraph 人机协同 |
| `langgraph-persistence` | LangGraph checkpointers, stores, memory, and time travel / LangGraph 持久化与记忆 |
| `langgraph-python-template` | Official LangGraph Python project templates / LangGraph Python 项目模板 |
| `llamaindex-rag-patterns` | LlamaIndex ingestion, retrieval, query engines, and evaluation / LlamaIndex RAG 模式 |
| `mem0` | Persistent memory for AI agents and applications / 智能体持久记忆 |

### Agent Agents / 智能体专用智能体

| Agent | Description / 描述 |
|-------|---------------------|
| `devkit:agent:langgraph` | LangGraph system and RAG builder / LangGraph 系统与 RAG 构建专家 |
| `devkit:agent:crewai` | CrewAI system and RAG builder / CrewAI 系统与 RAG 构建专家 |

### Agent Command / 智能体命令

| Command | Description / 描述 |
|---------|---------------------|
| `/devkit.agent` | Scaffold, build, or evaluate an AI agent / 构建、评估 AI 智能体 |

---

## Base Kit / 基础工具包

| Skill | Description / 描述 |
|-------|---------------------|
| `create-readme` | Generate comprehensive README files / 生成项目 README |
| `documentation-writer` | Write technical documentation / 编写技术文档 |
| `git-commit` | Generate well-structured commit messages / 生成规范的 Git 提交信息 |
| `grill-me` | Stress-test plans and designs with relentless questioning / 通过连续追问压测计划和设计 |

---

## Quick Start / 快速上手

1. Install the kit that matches your project / 安装与项目对应的工具包
2. Skills auto-trigger when Claude Code detects relevant context / 技能在 Claude Code 检测到相关上下文时自动触发
3. Use slash commands for intentional workflows / 使用斜杠命令执行有意的工作流

```bash
# Example: implement a Spring Boot feature / 示例：实现 Spring Boot 功能
/devkit.feature Add user registration endpoint with JWT auth

# Example: migrate frontend HTML/CSS / 示例：迁移原生前端
/devkit.frontend-migrate temp/

# Example: build an AI agent / 示例：构建 AI 智能体
/devkit.agent Build a RAG pipeline for document Q&A using LlamaIndex
```

## Contributing / 贡献

PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

欢迎提交 PR，参见贡献指南。

## License / 许可证

MIT License.
