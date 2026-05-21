# 同人小说创作应用 — MVP-0 设计文档（技术闭环验证）

- 文档编号：0002-mvp0-design
- 阶段：**MVP-0**（Week 0–6）
- 上游文档：[0001-design.md](0001-design.md)（全景设计） · [mvp.md](mvp.md) · [process.md](process.md)
- 下游文档：[0003-mvp1-design.md](0003-mvp1-design.md)（MVP-1 增量）· [0004-mvp2-design.md](0004-mvp2-design.md)（MVP-2 增量）
- 编写日期：2026-05-21

---

## 0. 本期目标与边界

### 0.1 一句话目标

> **1 个开发者本机 + 1 套 docker-compose 能跑通「导入原作 → 抽取实体 → 生成同人首章 → 完结回灌」的完整链路**。

### 0.2 本期 In-Scope（必交付）

| 维度       | MVP-0 范围                                                       |
| ---------- | ---------------------------------------------------------------- |
| 用户       | **单用户模式**（写死 demo user，不做注册登录 UI）                |
| 终端       | **仅 Web 端**（不打包桌面端）                                    |
| 部署       | 单机 docker-compose：postgres + pgvector + redis + minio         |
| 业务闭环   | Fandom → 导入 txt → 切章 + 摘要 + 抽取 → 审核 → 生成首章 → 完结  |
| AI 能力    | 文本清洗 / 章节切分 / 单章摘要 / 实体抽取 / 章节生成 / 章节摘要  |
| RAG        | 4 路检索 + Prompt 拼装（top-k 固定，不做 token 预算裁剪）        |
| 前端       | React SPA 最小可用页面，章节编辑器可简化为单栏                   |

### 0.3 本期 Out-of-Scope（MVP-1 / MVP-2 再做）

明确**不在 MVP-0 范围**，但代码与数据结构需为后期预留接口：

| 项                                          | 推迟到 | 备注                                  |
| ------------------------------------------- | ------ | ------------------------------------- |
| 注册 / 登录 / JWT / 多用户隔离              | MVP-1  | 但 `user_id` 字段在 schema 中保留     |
| Repository 模式与越权审查                   | MVP-1  | MVP-0 可直用 Prisma client，但接口先约定 |
| 桌面端 Tauri 壳                             | MVP-1  | 前端不做桌面专属分支                  |
| 章节自动保存 + 冲突 + 快照                  | MVP-1  | MVP-0 仅"显式保存"                    |
| 向量一致性巡检 / 编辑级联                   | MVP-1  | MVP-0 不删不改（接受 / 拒绝即可）     |
| Map-reduce 长摘要、Prompt 注入防护、模板版本管理 | MVP-1  | MVP-0 用单 prompt 文件                |
| Token 预算裁剪、配额限流、失败重试规则      | MVP-1+ | MVP-0 直接失败抛错                    |
| 创建向导（process.md 7 步）                 | MVP-1  | MVP-0 仅"必填三项直接进入"            |
| 安全 / 备份 / 数据生命周期 / 合规           | MVP-2  | —                                     |

---

## 1. 名词与缩写（MVP-0 核心）

| 术语                     | 含义                                              |
| ------------------------ | ------------------------------------------------- |
| Fandom                   | 原作知识库，对应一部原作。                        |
| Novel                    | 用户创作的同人或原创小说项目。                    |
| Volume / Chapter         | 分卷 / 章节，归属于 Novel。                       |
| ImportedChapter          | 从原作导入后切分出的原作章节。                    |
| ExtractionCandidate      | AI 抽取的候选实体（人物 / 世界观 / 事件）。       |
| Character / WorldSetting | 已审核入库的正式实体。                            |
| RAG                      | 基于向量检索的上下文增强生成。                    |
| GenerationTask           | 一次 AI 调用的任务记录。                          |
| VectorDocument           | 向量化文档分块。                                  |

（完整术语见 [0001-design.md §1](0001-design.md)）

---

## 2. 本期需求

### 2.1 用户故事（仅 MVP-0 必须的）

| 编号  | 用户故事                                                            | MVP-0 简化                                |
| ----- | ------------------------------------------------------------------- | ----------------------------------------- |
| US-02 | 创建 Fandom 知识库                                                  | 必填 name；type 可选；不做编辑            |
| US-03 | 上传 txt / md 或粘贴文本                                            | 仅 txt；≤ 5 MB；同步进度条而非 SSE         |
| US-04 | 章节切分与摘要                                                      | 同 [0001-design.md §2.3](0001-design.md)  |
| US-05 | 候选实体审核                                                        | 仅"接受 / 拒绝"，不支持编辑后接受 / 合并  |
| US-06 | 创建同人 Novel                                                      | 仅"跳过向导"入口，必填 title + fandomId   |
| US-07 | 章节大纲与生成                                                      | 不做流式（一次性返回也行）                |
| US-08 | 保存与完结章节                                                      | 必须做：完结后生成摘要并向量化            |

**本期不实现**：US-01（注册登录）、US-09（实体手动 CRUD）、US-10（生成历史页面）。

### 2.2 功能清单（按模块）

| 模块   | 编号 | 功能                                  | MVP-0 |
| ------ | ---- | ------------------------------------- | ----- |
| Fandom | F-10 | 新建 Fandom                           | ✅     |
| 导入   | F-20 | 上传 txt                              | ✅     |
| 导入   | F-22 | 章节切分                              | ✅     |
| 导入   | F-23 | 每章摘要                              | ✅     |
| 导入   | F-24 | 候选人物抽取                          | ✅     |
| 导入   | F-25 | 候选世界观抽取                        | ✅     |
| 审核   | F-30 | 候选列表 + 接受 / 拒绝                | ✅     |
| Novel  | F-50 | 新建小说                              | ✅     |
| 章节   | F-61 | Chapter CRUD                          | ✅     |
| 章节   | F-62 | AI 生成正文                           | ✅     |
| 章节   | F-63 | 完成本章（含摘要回灌）                | ✅     |
| 检索   | F-70 | 人物 / 世界观 / 摘要 embedding        | ✅     |
| 检索   | F-71 | RAG 检索注入 Prompt                   | ✅     |

### 2.3 非功能需求（MVP-0 仅核心）

| 类别       | 指标                                | 目标                                       |
| ---------- | ----------------------------------- | ------------------------------------------ |
| 性能：导入 | 10 万字 txt 端到端                  | ≤ 10 分钟（DoD 标准，比正式 MVP 宽松 1 倍） |
| 性能：生成 | 单章 3000 字                        | ≤ 180 秒（不要求流式）                     |
| 性能：检索 | top-k 向量检索                      | < 500 ms                                   |
| 可维护性   | TypeScript 端到端，核心模块单测     | 覆盖率 ≥ 40%                               |

> 安全 / 配额 / 备份 / 国际化 / 多浏览器兼容 / Sentry / Prometheus 等指标在 MVP-1 / MVP-2 中给出。

---

## 3. 架构（MVP-0 极简版）

### 3.1 部署拓扑

```
┌────────────────────────────────────────────────────────────┐
│  开发者浏览器 (Chrome / Edge)                              │
│  React SPA (Vite dev server，端口 5173)                    │
└──────────────────────────┬─────────────────────────────────┘
                           │ HTTP/JSON (localhost)
                           ▼
┌────────────────────────────────────────────────────────────┐
│  NestJS 后端 (Node.js 20，端口 3000)                       │
│  · Controllers / Services                                  │
│  · Prisma → PostgreSQL                                     │
│  · BullMQ → Redis                                          │
│  · LLM Client（直接调云端，无 Provider 抽象）              │
└────┬────────────────────┬────────────────────┬─────────────┘
     ▼                    ▼                    ▼
┌────────┐         ┌────────┐         ┌────────────────┐
│ Postgres│        │ Redis  │         │ MinIO          │
│ +pgvec  │        │        │         │ (上传原文存储) │
└────────┘         └────────┘         └────────────────┘
```

### 3.2 技术选型（MVP-0 锁定）

| 层         | 选型                            |
| ---------- | ------------------------------- |
| 前端       | React 19 + TypeScript + Vite    |
| UI         | Tailwind CSS + shadcn/ui        |
| 状态       | TanStack Query + Zustand        |
| 编辑器     | TipTap（用最简配置）            |
| 后端       | NestJS + Node.js 20             |
| ORM        | Prisma                          |
| 主库       | PostgreSQL 16 + pgvector        |
| 队列       | BullMQ + Redis 7                |
| 对象存储   | MinIO（docker-compose 一并起）  |
| LLM        | **任选一家**：OpenAI / DeepSeek（写死，不做抽象层） |
| Embedding  | `text-embedding-3-small`（1536 维）                |

完整选型权衡见 [0001-design.md §3.2 / §15](0001-design.md)。

### 3.3 后端模块划分（MVP-0 启用的）

```
api/             HTTP 控制器
modules/
  ├── fandom         Fandom CRUD
  ├── import         导入任务编排
  ├── extraction     候选实体抽取与审核
  ├── novel          小说项目
  ├── chapter        章节 CRUD + 生成 + 完结
  ├── rag            向量检索 + Prompt 拼装
  └── llm            LLM 调用客户端（写死单 Provider）
workers/
  ├── import-worker      导入流水线
  ├── embedding-worker   向量化
  └── generate-worker    章节生成 + 章节摘要
prompts/             单文件 prompt（不做 registry）
```

### 3.4 关键架构决策

- **单用户模式怎么实现**：在 NestJS middleware 写死注入 `request.userId = "demo-user-uuid"`，所有 service 假装从 request 拿；MVP-1 接入真鉴权时只改 middleware。
- **`user_id` 字段保留**：所有表 schema 里 `user_id` 都建好（值固定为 demo user），MVP-1 切换到多用户时**零迁移**。
- **不做 LLM Gateway 抽象**：直接调一家 Provider；MVP-1 再抽象 Gateway 接口。
- **不做 Prompt 模板注册表**：prompt 用 `.txt` 文件直接 import；MVP-1 再做 [§6.11 模板版本管理](0001-design.md#611-prompt-模板版本管理)。

---

## 4. 数据模型（MVP-0 必需表）

完全沿用 [0001-design.md §4](0001-design.md) 字段，但**仅创建本期使用的 11 张表**，并明确：

- 所有表保留 `user_id` 列（外键预留，MVP-0 全部指向同一个 demo user）。
- 不创建 `chapter_snapshots`（推迟到 MVP-1）。
- 不创建 `deletion_audit`（推迟到 MVP-2）。
- 不启用 RLS（推迟到 MVP-2）。

### 4.1 MVP-0 表清单

| 表名                    | 用途                  | 是否本期建表 | 完整字段定义                                              |
| ----------------------- | --------------------- | ------------ | --------------------------------------------------------- |
| `users`                 | 用户（仅 demo user）  | ✅ 建简化版  | [§4.2.1](0001-design.md#421-users)（仅 id + nickname 必填） |
| `fandoms`               | 原作知识库            | ✅           | [§4.2.2](0001-design.md#422-fandoms)                       |
| `novels`                | 小说项目              | ✅           | [§4.2.3](0001-design.md#423-novels)                        |
| `import_tasks`          | 导入任务              | ✅           | [§4.2.4](0001-design.md#424-import_tasks)                  |
| `imported_chapters`     | 导入的原作章节        | ✅           | [§4.2.5](0001-design.md#425-imported_chapters)             |
| `extraction_candidates` | 候选实体              | ✅           | [§4.2.6](0001-design.md#426-extraction_candidates)         |
| `characters`            | 人物卡                | ✅           | [§4.2.7](0001-design.md#427-characters)                    |
| `world_settings`        | 世界观                | ✅           | [§4.2.8](0001-design.md#428-world_settings)                |
| `volumes`               | 分卷                  | ✅           | [§4.2.9](0001-design.md#429-volumes)                       |
| `chapters`              | 同人章节              | ✅           | [§4.2.10](0001-design.md#4210-chapters)                    |
| `vector_documents`      | 向量库                | ✅           | [§4.2.12](0001-design.md#4212-vector_documents)            |
| `generation_tasks`      | AI 任务记录           | ✅           | [§4.2.13](0001-design.md#4213-generation_tasks)            |
| `writing_styles`        | 写作风格              | 🟡 建空表+默认行 | 仅"默认风格"行，不做 CRUD                                  |
| `chapter_snapshots`     | 章节快照              | ❌ 推迟      | MVP-1                                                     |
| `deletion_audit`        | 删除审计              | ❌ 推迟      | MVP-2                                                     |

### 4.2 简化决策

- **软删字段 `deleted_at`**：所有表都加，MVP-0 不用，MVP-1 才在 Repository 里启用过滤。
- **唯一约束**：保留全部约束（`(novel_id, chapter_no)` 等），不省。
- **索引**：MVP-0 只建主键 / 外键 / 唯一约束；ivfflat 向量索引必建（否则检索性能不达标）。性能复合索引 `(user_id, created_at desc)` 等推迟到 MVP-1。

### 4.3 demo user 初始化

数据库 migration 完成后跑一次 seed：

```sql
INSERT INTO users (id, email, nickname, password_hash, created_at, updated_at)
VALUES ('00000000-0000-0000-0000-000000000001',
        'demo@local',
        'Demo User',
        '<dummy-hash>',
        now(), now())
ON CONFLICT DO NOTHING;
```

---

## 5. 关键业务流程（MVP-0 必需）

### 5.1 创建 Fandom + 导入文本

完全沿用 [§5.2](0001-design.md#52-创建-fandom--导入文本异步流水线)，但简化：

```
[1] POST /fandoms                  → fandoms INSERT
[2] POST /fandoms/:id/imports      → 接收 multipart 文件
                                   → 落 MinIO
                                   → INSERT import_tasks (pending)
                                   → 投递 import-queue
[3] worker:import 顺序处理（不做并发）
    stage = cleaning   ：去 BOM、统一换行
    stage = splitting  ：规则切章 → 插 imported_chapters
    stage = summarizing：每章串行调 LLM 生成 summary
    stage = extracting ：每章串行抽取候选 → 插 extraction_candidates
    stage = embedding  ：每章 summary → vector_documents
    完成 → status = reviewing
[4] 前端轮询 GET /imports/:id（不做 SSE）
```

**章节切分规则**：完全沿用 [§5.2 章节切分规则](0001-design.md#52-创建-fandom--导入文本异步流水线)。

**简化点**：
- 摘要 / 抽取**串行**调用（MVP-1 改并发 5）。
- 失败直接整任务 `failed`，不做章节级重试（MVP-1 改成可重试）。

### 5.2 候选实体审核

```
GET  /imports/:id/candidates?type=CHARACTER&status=pending
POST /candidates/:id/approve    → 写 characters / world_settings + 触发 embedding
POST /candidates/:id/reject     → 标记 rejected
```

**简化点**：
- 不支持"编辑后接受"（前端只给两个按钮，MVP-1 加表单）。
- 不支持"合并到已有实体"（MVP-1 加）。
- 同名冲突时直接拒绝创建并返回 409，让用户手动 reject。

审核状态机沿用 [§5.3](0001-design.md#53-候选实体审核)，但只走 `approve` / `reject` 两条边。

### 5.3 创建 Novel：跳过向导

```
POST /novels { title, fandomId, type:"fanfic", fanficType?:"if" }
  ↓
后端事务内创建：
  · novels 行
  · 1 个 Volume "正文卷"（order_index=0）
  · 1 份默认 WritingStyle（name="默认风格"，其他字段为空字符串）
```

向导（process.md 7 步）推迟到 MVP-1。

### 5.4 章节 AI 生成（核心流程）

```
[1] PUT /chapters/:id              保存 outline / 出场人物 ID / 本章目标 / 额外要求
[2] POST /chapters/:id/generate    创建 GenerationTask(pending) + 投递 generate-queue
[3] worker:generate 处理
      a. 拉 Novel + WritingStyle + Chapter
      b. 构造 RAG query = title + outline + 出场人物名 + goal
      c. 顺序检索 4 路（MVP-0 不做并发）：
         - CHARACTER         top=5
         - WORLD_SETTING     top=5
         - IMPORTED_CHAPTER_SUMMARY  top=5
         - CHAPTER_SUMMARY   top=8（novel_id 过滤）
      d. 直接取最近 3 章 chapter.summary（chapter_no 降序）
      e. 渲染 Prompt（见 §6）
      f. 调 LLM（**非流式**），整段返回
      g. 写入 chapter.content（status 变 generated）
      h. GenerationTask.status = success
[4] 前端轮询 GET /generation-tasks/:id 或 GET /chapters/:id
```

**简化点**：
- **非流式**：MVP-0 不做 SSE；MVP-1 加流式输出。
- **不做 token 预算裁剪**：top-k 固定，超长直接靠 Provider 抛错（接受 MVP-0 偶发失败）。
- **不做失败重试**：失败就 `failed`，前端给"重新生成"按钮（实质是建新任务）。
- 自动覆盖 `chapter.content`，不做"应用 / 丢弃"二选一 UI。

### 5.5 完结章节与摘要回灌

完全沿用 [§5.6](0001-design.md#56-完成章节与摘要写库)：

```
POST /chapters/:id/complete
  → 投递 GENERATE_CHAPTER_SUMMARY 任务
  → worker 生成 200–400 字摘要 → 写 chapter.summary
  → INSERT vector_documents (source_type=CHAPTER_SUMMARY)
  → chapter.status = final
```

MVP-0 章节统一**短摘要**（≤ 6000 token 时直接一次调用），map-reduce 长摘要推迟到 MVP-1。

---

## 6. AI 能力（MVP-0 必需）

### 6.1 文本清洗

沿用 [§6.1](0001-design.md#61-文本清洗)。

### 6.2 章节切分

沿用 [§6.2 / §5.2 章节切分规则](0001-design.md#52-创建-fandom--导入文本异步流水线)。

### 6.3 三个核心 Prompt

| 用途         | Prompt                                                |
| ------------ | ----------------------------------------------------- |
| 单章摘要     | [§6.3](0001-design.md#63-摘要生成-prompt每章)         |
| 实体抽取     | [§6.4](0001-design.md#64-实体抽取-prompt每章合并一次调用输出-json) |
| 章节生成     | [§6.5](0001-design.md#65-章节生成-prompt关键)         |

**MVP-0 Prompt 管理方式**：
- 文件放在 `prompts/chapter/generate.txt`、`prompts/import/summarize.txt`、`prompts/import/extract.txt`。
- 启动时全部 `import` 进内存常量。
- 不做版本号、不做注册表、不做 A/B；MVP-1 再做 [§6.11](0001-design.md#611-prompt-模板版本管理)。

### 6.4 RAG 检索（简化版）

```
检索过滤：WHERE user_id = $1
       AND (fandom_id = $2 OR novel_id = $3)
       AND source_type IN (...)
       AND embedding IS NOT NULL
向量距离：cosine
top-k：见 §5.4 固定值
```

**MVP-0 不做**：
- Token 预算裁剪算法（[§6.7.2](0001-design.md#672-token-预算与裁剪算法)）
- RAG 审计字段 `rag_audit`（[§6.7.3](0001-design.md#673-prompt-装配审计)）
- 关键词混合检索（pg_trgm）

### 6.5 LLM 调用（裸版）

- 直接调一家 Provider 的 SDK。
- 重试：仅 SDK 自带的网络重试。
- 计费：仅记录 `generation_tasks.token_usage`（用于 DoD 验证），不做配额。
- 失败：直接 `generation_tasks.status = failed`，错误信息进 `error_message`。

完整失败处理 / 重试规则 / 配额限流见 [§6.8](0001-design.md#68-ai-调用成本配额限流与失败重试)，MVP-1 / MVP-2 接入。

---

## 7. API（MVP-0 端点清单）

通用约定沿用 [§7.1](0001-design.md#71-通用约定)，**但 MVP-0 鉴权简化为：所有请求自动注入 demo userId，不要求 Authorization 头**。

### 7.1 本期端点

| 模块      | 方法      | 路径                          | 说明                              |
| --------- | --------- | ----------------------------- | --------------------------------- |
| Fandom    | POST      | /fandoms                      | 新建                              |
| Fandom    | GET       | /fandoms                      | 列表                              |
| Fandom    | GET       | /fandoms/:id                  | 详情                              |
| Import    | POST      | /fandoms/:id/imports          | 创建导入任务 (multipart)          |
| Import    | GET       | /imports/:id                  | 任务详情 / 进度（轮询）           |
| Import    | GET       | /imports/:id/chapters         | 导入章节列表                      |
| Import    | GET       | /imports/:id/candidates       | 候选列表，支持 `?type=&status=`   |
| Candidate | POST      | /candidates/:id/approve       | 接受                              |
| Candidate | POST      | /candidates/:id/reject        | 拒绝                              |
| Novel     | POST      | /novels                       | 新建（含默认 Volume + Style）     |
| Novel     | GET       | /novels                       | 列表                              |
| Novel     | GET       | /novels/:id                   | 详情                              |
| Chapter   | POST      | /novels/:id/chapters          | 新建章节                          |
| Chapter   | GET       | /novels/:id/chapters          | 列表                              |
| Chapter   | GET       | /chapters/:id                 | 详情                              |
| Chapter   | PUT       | /chapters/:id                 | 全量更新 outline/content/title    |
| Chapter   | POST      | /chapters/:id/generate        | 触发 AI 生成（**返回 taskId**）   |
| Chapter   | POST      | /chapters/:id/complete        | 完结：生成摘要并向量化            |
| Task      | GET       | /generation-tasks/:id         | 单任务详情（前端轮询用）          |

**本期不提供**：
- `/auth/*`（推迟到 MVP-1）
- `/imports/:id/stream`（SSE，推迟到 MVP-1）
- `/chapters/:id/generate/stream`（SSE，推迟到 MVP-1）
- `/candidates/:id/merge`（推迟到 MVP-1）
- Character / WorldSetting / Style / Volume / GenerationTask 列表 / Settings 全部 CRUD（推迟到 MVP-1）

### 7.2 错误码（MVP-0 用到的）

| code                | HTTP | 说明           |
| ------------------- | ---- | -------------- |
| NOT_FOUND           | 404  | 资源不存在     |
| VALIDATION_FAILED   | 400  | 入参校验失败   |
| CONFLICT            | 409  | 唯一约束冲突   |
| LLM_PROVIDER_ERROR  | 502  | LLM 服务异常   |
| IMPORT_PARSE_FAILED | 422  | 文本无法切章   |
| INTERNAL_ERROR      | 500  | 兜底           |

`UNAUTHORIZED` / `FORBIDDEN` / `LLM_RATE_LIMITED` 等 MVP-1 / MVP-2 才用到。

---

## 8. 前端（MVP-0 最小可用）

### 8.1 页面清单

| 路由                        | 名称        | MVP-0 简化                                              |
| --------------------------- | ----------- | ------------------------------------------------------- |
| `/`                         | 工作台      | 一个新建按钮、一份最近列表足够                          |
| `/fandoms`                  | 知识库列表  | 卡片列表 + 新建                                         |
| `/fandoms/:id`              | Fandom 详情 | 单页：上传区 + 候选审核区 + 已入库实体表                |
| `/novels`                   | 我的小说    | 列表 + 新建                                             |
| `/novels/:id`               | 小说空间    | 单页：章节列表 + 概要                                   |
| `/novels/:id/chapters/:cid` | 章节编辑器  | **单栏布局**：大纲 textarea + 正文 textarea + 生成按钮  |

**本期不做**：
- `/login` / `/register`（推迟到 MVP-1）
- `/novels/new` 创建向导（推迟到 MVP-1）
- `/tasks` 生成历史（推迟到 MVP-1）
- `/settings`（推迟到 MVP-1）
- `/imports/:id/review` 四列审核（MVP-0 直接放到 fandom 详情里凑合）

### 8.2 章节编辑器（极简版）

```
┌───── 章节列表 ─────┬───────── 编辑区 ──────────┐
│ 第1章 雨夜         │ 标题：[输入框]            │
│ 第2章 ...          │ 大纲：[textarea]          │
│ [新建章节]         │ 出场人物：[多选下拉]      │
│                    │ 本章目标：[textarea]      │
│                    │ ─────────────────────     │
│                    │ [生成本章正文]            │
│                    │ ─────────────────────     │
│                    │ 正文：[textarea，可编辑]  │
│                    │                           │
│                    │ [保存]  [完成本章]        │
└────────────────────┴───────────────────────────┘
```

- 用 `<textarea>` 即可，不上 TipTap（推迟到 MVP-1，需要时再换）。
- 保存按钮直接 PUT 全量。无自动保存、无快照、无冲突处理。
- 生成中显示 spinner，完成后弹窗"正文已替换，请检查"。

### 8.3 状态管理

- TanStack Query 管所有 REST 调用，stale time 30 s。
- 任务进度 / 生成结果通过 `useQuery` 的 `refetchInterval: 2000` 轮询。

---

## 9. 非功能（MVP-0 范围）

### 9.1 性能指标（仅基线）

| 指标                            | MVP-0 目标 | 正式 MVP 目标 (MVP-1) |
| ------------------------------- | ---------- | --------------------- |
| 10 万字 txt 端到端导入          | ≤ 10 分钟  | ≤ 5 分钟              |
| 单章 3000 字生成（非流式）      | ≤ 180 秒   | ≤ 120 秒              |
| top-k 向量检索                  | < 500 ms   | < 300 ms              |

### 9.2 可观测性（最小）

- 后端用 console.log + NestJS 默认 logger 即可。
- 不接 Sentry / Prometheus（MVP-1 接入）。
- BullMQ 自带 dashboard 暴露在 `/admin/queues`（仅本地，无认证）。

### 9.3 安全（最小）

- **不做任何安全控制**。CORS 允许 `*`；上传无 MIME 检查；MinIO 默认 access key。
- 这是 MVP-0 的明确取舍：dogfood 环境不暴露公网。**禁止把 MVP-0 部署到任何对外可访问的环境**。

完整安全策略 / 配额 / 审计见 [§6.10 / §10.2 / §10.6](0001-design.md)，MVP-1 / MVP-2 实施。

---

## 10. 完成定义（DoD）

完全沿用 [§12.2 MVP-0 DoD](0001-design.md#122-mvp-0技术闭环验证week-06)：

1. **导入链路达标**：在本地用 10 万字 txt 走完一遍，端到端 ≤ 10 分钟。
2. **RAG 闭环验证**：第二章生成时，输出中能明确引用第一章发生的事件。
3. **代码质量**：关键代码通过 lint + 单测覆盖率 ≥ 40%。

### 10.1 验收脚本（手工跑一次）

1. docker-compose up 启动全部依赖。
2. `pnpm migrate && pnpm seed` 建表 + 写入 demo user。
3. 浏览器打开 `localhost:5173`。
4. 新建 Fandom《XX》→ 上传 5–10 万字 txt → 等待 → 进入 Fandom 详情。
5. 至少看到 ≥ 5 个候选人物、≥ 5 个候选世界观、每章摘要齐全。
6. 接受 ≥ 3 个人物和 ≥ 3 个世界观。
7. 新建 Novel 关联该 Fandom → 进入章节编辑器。
8. 新建第一章，填大纲 + 出场人物 + 目标 → 点"生成本章正文" → ≤ 180 秒得到 ≥ 2000 字正文。
9. 点"完成本章" → 状态变 `final` → 摘要可见。
10. 新建第二章，再次生成 → 输出明确引用第一章事件（**关键 RAG 验证点**）。

---

## 11. 风险与对策（MVP-0 优先关注）

| 风险                               | 影响                       | MVP-0 对策                                |
| ---------------------------------- | -------------------------- | ----------------------------------------- |
| LLM 单次调用超长 / 上下文溢出      | 章节生成大面积失败         | top-k 固定，文本字段长度上限硬编码        |
| 章节切分错误                       | 知识库噪声                 | 切分前在 import_tasks.stage 留检查点      |
| AI 抽取 JSON 解析失败              | 候选缺失                   | 抽取调用做 1 次"只输出 JSON"重试，仍失败标章节 failed |
| 向量检索结果与预期不符（RAG 不闭环）| DoD #2 不通过              | DoD 验收前先做一组离线测试集               |
| Provider 选型踩坑（成本 / 限流）   | 整个验收阶段被卡           | 同时准备 OpenAI + DeepSeek 两套 API key，单 Provider 出问题立刻切 |

完整风险矩阵见 [§11](0001-design.md#11-风险权衡与缓解)。

---

## 12. 下一期预告

MVP-0 跑通后，[0003-mvp1-design.md](0003-mvp1-design.md) 将在此基础上叠加：

- 注册 / 登录 / 多用户隔离（Repository 模式 + 越权审查）
- 桌面端 Tauri 壳 + 凭据存储
- 章节自动保存 + 冲突处理 + 快照表
- 向量一致性维护（编辑 / 删除级联 + 巡检任务）
- Map-reduce 长摘要、Prompt 注入防护、模板版本管理
- Token 预算裁剪、失败重试、流式输出
- 创建向导（7 步引导）
- LLM Provider 配置（用户自带 Key）
- Sentry + Prometheus 可观测

---

文档结束。
