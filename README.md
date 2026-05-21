# Fiction Studio — 同人小说创作应用

一个为同人作者打造的"原作知识库 + AI 写作"一体化工具。把**原作 → 知识库 → 同人生成**做成闭环，让 AI 在每次生成时都"看过"原作设定和已写章节，避免 OOC、设定串台、长篇遗忘前情。

> **当前状态**：MVP-0 S0 已启动。仓库已初始化 pnpm workspace、NestJS API、Vite React Web 与本地 docker-compose 依赖。

---

## 这个项目解决什么问题

同人创作者面临三个核心痛点：

1. **原作设定记不全**：人物性格、世界观规则、关键事件分散在原文里，写作时反复翻书。
2. **AI 工具"不懂"原作**：直接用通用 ChatGPT 写同人，容易 OOC、设定串台。
3. **多章节连续生成困难**：写到第 10 章时，AI 已经忘了第 3 章发生过什么。

价值主张 — 把原作设定向量化、做 RAG、注入 Prompt，让 AI 始终"看过"全局。

---

## 文档导航

所有设计文档在 [specs/](specs/) 目录下。**第一次来请按以下顺序阅读**：

| 顺序 | 文档 | 内容 |
| ---- | ---- | ---- |
| 1 | [specs/mvp.md](specs/mvp.md) | 业务输入：功能列表与 MVP 范围定义 |
| 2 | [specs/process.md](specs/process.md) | 业务输入：用户创建小说的 7 步流程 |
| 3 | [specs/0001-design.md](specs/0001-design.md) | **完整设计全景**（约 2300 行）：需求 / 架构 / 数据 / 流程 / Prompt / 安全 / 生命周期 / 选型替代 |

### 分期实施方案

[0001-design.md](specs/0001-design.md) 的内容过于庞大、各种关注点交织。**实际落地按下面三期拆分**，每一期都是一个可独立上线的版本：

| 阶段 | 文档 | 周期 | 目标 | 交付物 |
| ---- | ---- | ---- | ---- | ------ |
| **MVP-0** | [0002-mvp0-design.md](specs/0002-mvp0-design.md) | Week 0–6 | 跑通技术闭环，内部 dogfood | 单用户 + Web + 最简流程能生成一章 |
| **MVP-1** | [0003-mvp1-design.md](specs/0003-mvp1-design.md) | Week 6–12 | 完整 MVP 体验，可邀测 | 多用户、桌面端、完整 RAG、自动保存/快照、向量一致性 |
| **MVP-2** | [0004-mvp2-design.md](specs/0004-mvp2-design.md) | Week 12–18 | 准生产，对外可注册 | 完整安全、配额、备份、生命周期、合规 |

MVP-1 / MVP-2 文档为**增量 diff**：只描述相对前一期新增 / 修改 / 启用的部分，完整字段、Prompt 全文、详细规则请回到 [0001-design.md](specs/0001-design.md) 对应锚点。

---

## 核心技术决策（一句话版）

完整选型与替代方案见 [0001-design.md §3.2](specs/0001-design.md) 与 [§15](specs/0001-design.md)。

- **双形态部署**：同一份 React SPA + 同一份 NestJS 后端 + 不同壳（Web 浏览器 / Tauri WebView2 桌面）。
- **同库一站式**：PostgreSQL 16 + pgvector，业务表和向量表同事务一致；BullMQ + Redis 跑异步任务。
- **LLM Provider 抽象**：用户可在设置切换 OpenAI / Claude / DeepSeek / Qwen，或自带 API Key。
- **数据隔离三道防线**：路由 AuthGuard + Repository 强制注入 user_id + Postgres RLS（MVP-2 启用）。
- **Prompt 即资产**：版本化管理（`registry.yaml` + `.vN.txt`），旧版本永久保留，所有任务记录 `prompt_template_version`。

---

## 目录结构

```
fiction/
├── README.md                          ← 你正在读
├── apps/
│   ├── api/                            NestJS 后端
│   └── web/                            Vite React 前端
├── packages/
│   └── shared/                         前后端共享类型
├── docker-compose.yml                  本地 postgres + redis + minio
├── pnpm-workspace.yaml                 pnpm workspace
└── specs/
    ├── mvp.md                         业务输入：功能与 MVP 范围
    ├── process.md                     业务输入：创建流程 7 步
    ├── demo.txt                       原始素材（导入测试用文本）
    ├── 0001-design.md                 完整设计全景（最终形态）
    ├── 0001-design-back.md            旧版备份（可归档）
    ├── 0002-mvp0-design.md            MVP-0 独立设计（Week 0–6）
    ├── 0003-mvp1-design.md            MVP-1 增量设计（Week 6–12）
    └── 0004-mvp2-design.md            MVP-2 增量设计（Week 12–18）
```

后续阶段会继续扩展为：

```
fiction/
├── README.md
├── specs/                             设计文档（持续更新）
├── docs/                              开发者文档（ADR、运维手册等）
│   ├── adr/                           架构决策记录
│   └── export-schema-CHANGELOG.md     导出格式变更日志
├── apps/
│   ├── web/                           React SPA
│   ├── desktop/                       Tauri 壳
│   └── api/                           NestJS 后端
├── packages/
│   ├── prompts/                       Prompt 模板与 registry
│   └── shared/                        前后端共享类型
├── apps/api/prisma/                   schema 与迁移
└── docker-compose.yml                 本地一键起 postgres + redis + minio
```

---

## 开始开发

前置依赖：

- Node.js `22.22.3`
- Corepack / pnpm
- Docker Desktop（用于 postgres / redis / minio）

```bash
corepack enable pnpm
pnpm install
cp .env.example .env
docker compose up -d
pnpm --filter api prisma generate
pnpm --filter api prisma migrate dev --name init
pnpm dev
```

常用命令：

```bash
pnpm --filter api dev
pnpm --filter web dev
pnpm --filter api build
pnpm --filter web build
pnpm --filter api lint
pnpm --filter web lint
pnpm --filter api llm:ping
```

本地入口：

- Web: `http://localhost:5173`
- API health: `http://localhost:3000/health`
- BullMQ Dashboard: `http://localhost:3000/admin/queues`

LLM 调用使用 OpenAI 兼容接口，在 `.env` 中配置：

```bash
LLM_API_KEY=
LLM_MODEL=
LLM_BASE_URL=
```

---

## 不在范围内（MVP 阶段）

明确**不做**的事，避免范围蔓延（完整列表见 [0001-design.md §2.6](specs/0001-design.md) 与 [§12.5](specs/0001-design.md)）：

- 自动 CP / 伏笔 / 关系图谱、OOC 检测、AI 味评分
- epub / pdf / docx 高级解析（仅支持 txt / md / 粘贴）
- 全文相似度、版本对比、自动发布、多人协作、富文本批注
- 移动端、本地后端模式（SQLite + sqlite-vec）

---

## 文档维护约定

- 设计文档（specs/）的修改必须通过 PR review。
- [0001-design.md](specs/0001-design.md) 是最终形态的 source of truth；分期文档只描述边界与增量。
- Prompt 模板变更走 [§6.11 模板版本管理](specs/0001-design.md) 的"新增 .vN.txt + 改 registry.yaml" 流程，**不**允许覆盖旧版本。
- 技术选型变更记录到 `docs/adr/`（待建立），每季度回顾一次。
