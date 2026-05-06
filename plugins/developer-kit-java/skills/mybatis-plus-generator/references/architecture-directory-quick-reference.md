# 架构目录快速参考

本文档提供不同架构类型下，各种对象类型的快速目录映射参考。

> **COLA V5 映射与 `ddd-cola` skill 保持一致**，遵循 COLA V5 官方命名约定（`app`、`gateway`、`adapter/controller`）。

## 快速查找表

### Entity（实体类）

| 架构类型 | 目录路径 |
|:--------|:---------|
| MVC | `{package}/entity/` |
| DDD | `{package}/domain/model/aggregate/{entity}/` 或 `{package}/domain/model/entity/` |
| 六边形 | `{package}/domain/model/entity/` |
| 整洁 | `{package}/domain/entity/` |
| COLA | `{package}/domain/model/entity/` |

### Mapper（数据访问接口）

| 架构类型 | 目录路径 |
|:--------|:---------|
| MVC | `{package}/mapper/` |
| DDD | `{package}/domain/repository/`（仓储接口）<br>`{package}/infrastructure/persistence/mapper/`（MyBatis Mapper） |
| 六边形 | `{package}/application/ports/outbound/`（端口接口）<br>`{package}/infrastructure/adapter/outbound/persistence/mapper/`（MyBatis Mapper） |
| 整洁 | `{package}/application/ports/output/` 或 `{package}/domain/repository/`（接口）<br>`{package}/infrastructure/persistence/mapper/`（MyBatis Mapper） |
| COLA | `{package}/domain/gateway/`（网关接口，COLA 使用 gateway 不是 repository）<br>`{package}/infrastructure/persistence/mapper/`（MyBatis Mapper 实现） |

### Service（服务接口）

| 架构类型 | 目录路径 |
|:--------|:---------|
| MVC | `{package}/service/` |
| DDD | `{package}/application/service/` |
| 六边形 | `{package}/application/ports/inbound/` |
| 整洁 | `{package}/application/usecase/{entity}/` |
| COLA | `{package}/app/service/`（COLA V5 使用 app 不是 application） |

### ServiceImpl（服务实现类）

| 架构类型 | 目录路径 |
|:--------|:---------|
| MVC | `{package}/service/impl/` |
| DDD | `{package}/application/service/impl/` |
| 六边形 | `{package}/application/services/` |
| 整洁 | `{package}/application/service/` |
| COLA | `{package}/app/service/impl/`（COLA V5 使用 app 不是 application） |

### Controller（控制器）

| 架构类型 | 目录路径 |
|:--------|:---------|
| MVC | `{package}/controller/` |
| DDD | `{package}/interfaces/web/controller/` |
| 六边形 | `{package}/infrastructure/adapter/inbound/web/controller/` |
| 整洁 | `{package}/infrastructure/web/controller/` |
| COLA | `{package}/adapter/controller/`（COLA V5 直接在 adapter 下，不是 adapter/web/） |

### DTO（数据传输对象）

| 架构类型 | 目录路径 |
|:--------|:---------|
| MVC | `{package}/dto/` |
| DDD | Request: `{package}/interfaces/web/dto/request/`<br>Response: `{package}/interfaces/web/dto/response/` |
| 六边形 | `{package}/infrastructure/adapter/inbound/web/dto/` |
| 整洁 | `{package}/infrastructure/web/dto/` 或 `{package}/application/dto/` |
| COLA | `{package}/adapter/dto/` 或 `{package}/app/model/dto/` |

### VO（视图对象）

| 架构类型 | 目录路径 |
|:--------|:---------|
| MVC | `{package}/vo/` |
| DDD | `{package}/interfaces/web/dto/response/` |
| 六边形 | `{package}/infrastructure/adapter/inbound/web/dto/` |
| 整洁 | `{package}/infrastructure/web/dto/` |
| COLA | `{package}/adapter/dto/` |

### BO（业务对象）

| 架构类型 | 目录路径 |
|:--------|:---------|
| MVC | `{package}/bo/` |
| DDD | `{package}/application/dto/` |
| 六边形 | `{package}/application/dto/` |
| 整洁 | `{package}/application/dto/` |
| COLA | `{package}/app/model/` 或 `{package}/app/executor/`（COLA V5 使用 app 不是 application） |

### Persistence Entity（持久化实体）

**注意**：仅在 DDD、六边形、整洁、COLA 架构中需要区分领域实体和持久化实体。

| 架构类型 | 目录路径 |
|:--------|:---------|
| DDD | `{package}/infrastructure/persistence/entity/` |
| 六边形 | `{package}/infrastructure/adapter/outbound/persistence/entity/` |
| 整洁 | `{package}/infrastructure/persistence/entity/` |
| COLA | `{package}/infrastructure/persistence/entity/` |

### Repository/Gateway Implementation（仓储/网关实现）

| 架构类型 | 目录路径 |
|:--------|:---------|
| DDD | `{package}/infrastructure/persistence/repository/` |
| 六边形 | `{package}/infrastructure/adapter/outbound/persistence/repositoryimpl/` |
| 整洁 | `{package}/infrastructure/persistence/repository/` |
| COLA | `{package}/infrastructure/persistence/mapper/`（Gateway 实现通过 MyBatis Mapper） |

## 完整路径示例

假设基础包路径为 `com.example.order`，表名为 `user`：

### MVC 架构

```
src/main/java/com/example/order/
├── entity/User.java
├── mapper/UserMapper.java
├── service/UserService.java
├── service/impl/UserServiceImpl.java
├── controller/UserController.java
└── dto/UserCreateDTO.java
```

### DDD 架构

```
src/main/java/com/example/order/
├── domain/
│   ├── model/aggregate/user/User.java
│   └── repository/UserRepository.java
├── application/
│   ├── service/UserApplicationService.java
│   └── service/impl/UserApplicationServiceImpl.java
├── interfaces/web/
│   ├── controller/UserController.java
│   └── dto/
│       ├── request/UserCreateRequest.java
│       └── response/UserResponse.java
└── infrastructure/persistence/
    ├── entity/UserEntity.java
    └── mapper/UserMapper.java
```

### 六边形架构

```
src/main/java/com/example/order/
├── domain/model/entity/User.java
├── application/
│   ├── ports/
│   │   ├── inbound/IUserService.java
│   │   └── outbound/IUserRepository.java
│   └── services/UserServiceImpl.java
└── infrastructure/adapter/
    ├── inbound/web/
    │   ├── controller/UserController.java
    │   └── dto/UserRequest.java
    └── outbound/persistence/
        ├── repositoryimpl/UserRepositoryImpl.java
        ├── mapper/UserMapper.java
        └── entity/UserEntity.java
```

### 整洁架构

```
src/main/java/com/example/order/
├── domain/entity/User.java
├── application/
│   ├── usecase/user/CreateUserUseCase.java
│   ├── ports/output/UserOutputPort.java
│   └── service/UserApplicationService.java
└── infrastructure/
    ├── persistence/
    │   ├── repository/UserRepositoryImpl.java
    │   ├── mapper/UserMapper.java
    │   └── entity/UserEntity.java
    └── web/
        ├── controller/UserController.java
        └── dto/UserWebRequest.java
```

### COLA V5 架构（与 ddd-cola skill 对齐）

```
src/main/java/com/example/order/
├── adapter/
│   ├── controller/UserController.java
│   ├── scheduler/
│   └── dto/
│       ├── UserCreateRequest.java
│       └── UserResponse.java
├── app/
│   ├── executor/
│   │   ├── command/user/UserCreateCmdExe.java
│   │   └── query/user/UserGetQryExe.java
│   ├── service/UserAppService.java
│   └── service/impl/UserAppServiceImpl.java
├── domain/
│   ├── model/entity/User.java
│   ├── gateway/UserGateway.java
│   └── service/
└── infrastructure/
    ├── persistence/
    │   ├── mapper/UserMapper.java
    │   └── entity/UserDO.java
    ├── external/
    └── config/
```

## COLA V5 命名约定对照

> 与 `ddd-cola` skill 保持一致

| 概念 | COLA V5 命名 | 其他架构常见命名 | 说明 |
|:-----|:------------|:---------------|:-----|
| 应用层 | `app` | `application` | COLA V5 使用简短命名 |
| 仓储接口 | `gateway` | `repository` | COLA 使用 Gateway 术语 |
| 控制器目录 | `adapter/controller/` | `adapter/web/controller/` | COLA 扁平化组织 |
| 命令对象 | `Cmd` 后缀 | `Command` / `Request` | 如 `CreateUserCmd` |
| 查询对象 | `Qry` 后缀 | `Query` / `Request` | 如 `GetUserQry` |
| 执行器 | `Exe` 后缀 | `Handler` / `UseCase` | 如 `UserCreateCmdExe` |
| 持久化对象 | `DO` 后缀 | `Entity` / `PO` | 如 `UserDO` |

## 使用步骤

1. **确认架构类型**（从 Step 2 获取）
2. **确认基础包路径**（从 Step 1 获取）
3. **查找对象类型**（Entity、Mapper、Service 等）
4. **使用上表查找对应目录路径**
5. **构建完整路径**：`src/main/java/{package}/{目录路径}/{ClassName}.java`
6. **验证目录存在**，不存在则创建
7. **生成文件**

## 注意事项

1. **领域实体 vs 持久化实体**：
   - DDD、六边形、整洁、COLA 架构需要区分
   - 领域实体包含业务逻辑，放在领域层
   - 持久化实体是数据库映射，放在基础设施层

2. **Mapper 接口位置**：
   - 在 DDD、六边形、整洁架构中，通常有两个位置：
     - 仓储接口（领域层定义）
     - MyBatis Mapper（基础设施层实现）
   - 在 COLA 中，Gateway 在领域层定义，Mapper 在基础设施层实现

3. **DTO 分类**：
   - DDD 架构中，Request 和 Response 分开存放
   - COLA 中 DTO 放在 adapter/dto/ 或 app/model/ 中

4. **包路径转换**：
   - 包路径使用点分隔：`com.example.order`
   - 文件路径使用斜杠分隔：`com/example/order/`
   - 基础路径：`src/main/java/`

5. **COLA V5 特殊约定**：
   - 应用层包名使用 `app`（不是 `application`）
   - 仓储接口使用 `gateway`（不是 `repository`）
   - 控制器直接放在 `adapter/controller/`（不是 `adapter/web/controller/`）

## 参考文档

- 详细映射指南：`architecture-directory-mapping-guide.md`
- 详细示例：`examples/architecture-directory-mapping.md`
- COLA V5 权威参考：`../../ddd-cola/SKILL.md`
- DDD 架构参考：`../ddd4j-project-creator/docs/1、DDD 经典分层架构目录结构.md`
- 六边形架构参考：`../ddd4j-project-creator/docs/2、六边形架构详细目录结构参考.md`
- 整洁架构参考：`../ddd4j-project-creator/docs/3、整洁架构详细目录结构参考.md`
- COLA V5 架构参考：`../ddd4j-project-creator/docs/4、COLA V5 架构详细目录结构参考.md`