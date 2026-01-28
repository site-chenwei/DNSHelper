# AI Rules & Code Conventions (SSOT)

本项目遵循单一事实来源 (Single Source of Truth) 原则。此文件包含了**当前项目 (HarmonyOS)** 的开发规范，以及用户全局的**技术栈偏好 (Backend/Frontend)**，作为所有项目的通用参考手册。

---

## 1. 核心交互与工作流 (Core Workflow)
*适用于所有项目*

- **语言协议**:
  - **全中文输出**: 思考过程、工具参数、Todo 列表、代码注释、Git 提交信息必须使用中文。
- **Git 工作流**:
  - **严格被动提交 (Explicit Commit Only)**: 仅在用户明确指令下执行 Commit/Push。
  - **分支管理**: 自动删除无用分支 (Auto-Delete)。
- **记忆维护**:
  - 新规范必须写入 `AI_RULES.md`。

---

## 2. 当前项目规范: HarmonyOS (ArkTS)
*Priority: High (Current Context)*

- **命名规范**:
  - **PascalCase**: 类 (Class)、接口 (Interface)、枚举 (Enum)、组件 (Component/Page)。
  - **camelCase**: 变量、方法、TS 文件。
  - **UPPER_SNAKE_CASE**: 常量。
  - **snake_case**: 资源文件 (如 `ic_back.png`)。

- **ArkTS 编码原则**:
  - **类型安全**: 严禁 `any`。入参 > 2 个时使用 Interface/DTO。
  - **UI 开发**:
    - 优先使用 `@Builder` 复用 UI。
    - 状态管理: `@State` (组件内), `@Prop` (单向), `@Link` (双向)。
    - 必须启用 `strictMode` (build-profile.json5)。

- **工程结构**:
  ```text
  entry/src/main/ets/
  ├── entryability/     # 入口
  ├── pages/            # 页面
  ├── components/       # 通用组件
  ├── model/            # DTO/Entity
  ├── services/         # 业务逻辑
  └── utils/            # 工具类
  ```

---

## 3. 全局技术栈规范 (Global Reference)
*适用于涉及相应技术栈的项目*

### 3.1 后端开发规范 (Java / Spring Boot)
- **技术栈**: Java, Spring Boot, Gradle (Wrapper v9.3, 阿里云镜像), JPA。
- **编码规范**:
  - **DTO**: 入参 > 2 个必用 DTO，禁止路径参数，按业务分包。
  - **对象转换**: 强制使用 `MapStruct`，接口名以 `Mapping` 结尾。
  - **数据库**: 表名统一 `tb_` 前缀。
  - **质量**: 严禁魔法值，使用 Slf4j，Optional 防 NPE，卫语句减少嵌套。
- **架构规范**:
  - **Controller**: 无业务逻辑，仅负责参数接收与 Service 调用。列表查询必分页。
  - **Service**: 接口先行 (Interface-First)，命名 `I` 开头，必须包含 Javadoc。
  - **Global**: 统一 ApiResponse，全局异常处理，禁止 Controller 直调 Repository。
  - **权限**: RBAC 模型，Auth Token 认证。

### 3.2 前端开发规范 (React / Umi)
- **技术栈**: React, Umi Max, Ant Design Pro。
- **核心规范**:
  - **组件**: 强制函数式组件 + Hooks，优先解构 Props。
  - **状态管理**: 使用 `useModel`。
  - **网络请求**: 使用 Umi Request。
    - Service URL 必须通过 Enum (`ApiUrl`) 获取。
    - Token 存 SessionStorage。
  - **工程配置**:
    - 路由守卫使用 Wrappers。
    - `tsconfig` 开启 `skipLibCheck`。
    - Proxy 不重写路径。
  - **质量**: 强制 ESLint，严禁 `any`，全局拦截 API 错误。

---

## 4. 通用代码质量原则 (General Quality)
*适用于所有语言*

- **Clean Code**:
  - 严禁魔法值 (Magic Values)，必须提取常量。
  - 优先使用卫语句 (Guard Clauses)。
- **开发原则**:
  - **开源优先**: 优先使用成熟开源依赖。
  - **注释**: 必须使用中文，简洁明了。
