# MVP-0 执行计划

- 文档编号：0002-mvp0-plan
- 配套设计：[0002-mvp0-design.md](0002-mvp0-design.md)
- 上游全景：[0001-design.md](0001-design.md)
- 周期：Week 0–6（约 30 个开发日）
- 假设：**1 个开发者全职投入**；估时单位为人天（d）；总和约 28d，留 2d 缓冲

---

## 0. 阅读说明

本计划把 [0002-mvp0-design.md](0002-mvp0-design.md) 全部交付物拆为**可执行任务**，并按依赖顺序排列。每条任务给出：

- **ID**：`MVP0-XX`，便于追踪。
- **依赖**：必须先完成的任务 ID。空格分隔。
- **估时**：人天（0.25d / 0.5d / 1d / 2d）。
- **产出**：完成标志，可被他人验证。
- **设计依据**：对应设计文档锚点。

任务编排原则：

1. **先打地基，再上业务**：infra → schema → 基础 CRUD → 流水线 → AI → 前端 → 验收。
2. **AI 闭环越早跑通越好**：在前端铺开前先用 Postman / curl 把一条完整生成链路跑通，否则前端做完了 AI 不闭环就崩盘。
3. **测试不留到最后**：每个 P0 模块的单测随模块走，不集中补。

---

## 1. 阶段总览

| 阶段 | 周次 | 主题 | 关键产出 | 累计人天 |
| ---- | ---- | ---- | -------- | -------- |
| **S0** | Week 0 | 基础设施与项目骨架 | docker-compose 起得来；NestJS / Vite 能跑空白页 | 3d |
| **S1** | Week 1 | 数据层与基础 CRUD | Prisma schema 完成；Fandom / Novel / Chapter CRUD 接口可用 | 7d |
| **S2** | Week 2–3 | 导入流水线 + AI 抽取 | 上传 txt → 切章 → 摘要 → 抽取 → 审核 全链路可用 | 14d |
| **S3** | Week 3–4 | RAG + 章节生成 + 完结 | 章节生成 + 摘要回灌闭环；DoD #2 通过 | 21d |
| **S4** | Week 4–5 | 前端最小可用 | 6 个页面全部接通后端；可用浏览器走完手工验收脚本 | 27d |
| **S5** | Week 5–6 | 验收与收尾 | DoD 全部通过 + 单测 ≥ 40% + 已知问题清单 | 30d |

---

## 2. 任务清单（按依赖顺序）

### S0：基础设施与项目骨架（3d）

| ID | 任务 | 依赖 | 估时 | 产出 | 设计依据 |
| -- | ---- | ---- | ---- | ---- | -------- |
| MVP0-01 | 仓库布局与 monorepo 工具选型（pnpm workspace） | — | 0.25d | `pnpm-workspace.yaml`、`apps/api`、`apps/web`、`packages/shared` 空壳 | §3.3 |
| MVP0-02 | docker-compose：postgres 16 + pgvector + redis 7 + minio | — | 0.5d | `docker-compose.yml`；`docker-compose up` 起得来；可用 psql / redis-cli / mc 连接 | §3.1 |
| MVP0-03 | NestJS 后端骨架（Node 20 + TS + ESLint + Prettier） | MVP0-01 | 0.5d | `pnpm --filter api dev` 起 3000 端口，`GET /health` 返回 200 | §3.2 §3.3 |
| MVP0-04 | Vite + React 19 + TS 前端骨架 + Tailwind + shadcn/ui 初始化 | MVP0-01 | 0.5d | `pnpm --filter web dev` 起 5173 端口，能看到空白页 | §3.2 |
| MVP0-05 | Prisma 接入 + 连接 docker postgres + 初始化空 schema | MVP0-02 MVP0-03 | 0.25d | `pnpm prisma migrate dev` 空跑无报错 | §3.2 |
| MVP0-06 | BullMQ 接入 + redis 连通 + 一个 noop queue 通跑 | MVP0-02 MVP0-03 | 0.5d | 启动后可在 redis 看到 BullMQ 注册的 key；`/admin/queues` Dashboard 暴露 | §3.3 §9.2 |
| MVP0-07 | LLM 客户端接入（OpenAI 或 DeepSeek 二选一）+ 一个 echo 测试 | MVP0-03 | 0.5d | `LlmClient.complete("ping")` 在测试脚本中正常返回；API key 走 `.env` | §3.2 §6.5 |

**S0 出口标准**：`docker-compose up` + `pnpm dev` 后，前后端均可访问；LLM 客户端能通 1 次真实调用；BullMQ Dashboard 可见。

---

### S1：数据层与基础 CRUD（4d）

| ID | 任务 | 依赖 | 估时 | 产出 | 设计依据 |
| -- | ---- | ---- | ---- | ---- | -------- |
| MVP0-08 | Prisma schema：13 张表（users / fandoms / novels / volumes / chapters / writing_styles / import_tasks / imported_chapters / extraction_candidates / characters / world_settings / vector_documents / generation_tasks） | MVP0-05 | 1d | `prisma migrate` 生成完整 schema；所有表含 `user_id` 与 `deleted_at` 列；唯一约束齐全 | §4.1 §4.2 |
| MVP0-09 | pgvector 扩展启用 + `vector_documents.embedding` 列 + ivfflat 索引 | MVP0-08 | 0.5d | `CREATE EXTENSION vector;` 已迁移；ivfflat 索引建立 | §4.2 §4.3 |
| MVP0-10 | demo user seed 脚本 + middleware 写死 `request.userId` | MVP0-08 | 0.25d | `pnpm seed` 写入 demo user；任意控制器内 `req.userId === demo uuid` | §3.4 §4.3 |
| MVP0-11 | Fandom 模块：POST / GET 列表 / GET 详情 | MVP0-10 | 0.5d | 三个端点 200 通；带 user_id 过滤 | §5.1 §7.1 |
| MVP0-12 | Novel 模块：POST（事务内建 Volume + 默认 WritingStyle）+ GET 列表 / 详情 | MVP0-11 | 0.75d | 一次 POST 生成 1 novel + 1 volume + 1 default style；事务回滚测试通过 | §5.3 |
| MVP0-13 | Chapter 模块：POST / GET 列表 / GET 详情 / PUT（全量更新） | MVP0-12 | 0.5d | `(novel_id, chapter_no)` 唯一约束生效；PUT 不带版本号 | §5.4 §7.1 |
| MVP0-14 | 错误处理统一：全局 ExceptionFilter + 错误码枚举 + DTO 验证（class-validator） | MVP0-11 | 0.5d | NOT_FOUND / VALIDATION_FAILED / CONFLICT / INTERNAL_ERROR 四类返回结构一致 | §7.2 |

**S1 出口标准**：用 curl 走通 `POST /fandoms → POST /novels → POST /novels/:id/chapters → PUT /chapters/:id`。

---

### S2：导入流水线 + AI 抽取（7d）

| ID | 任务 | 依赖 | 估时 | 产出 | 设计依据 |
| -- | ---- | ---- | ---- | ---- | -------- |
| MVP0-15 | MinIO 客户端封装 + 上传 / 下载 API | MVP0-02 MVP0-03 | 0.5d | `StorageService.put(buf) / get(key)` 单测通过 | §3.1 |
| MVP0-16 | `POST /fandoms/:id/imports`：接收 multipart → 落 MinIO → 插 import_tasks → enqueue | MVP0-11 MVP0-15 | 0.75d | 上传 demo.txt 后表里有一条 pending 行 + queue 收到 job | §5.1 |
| MVP0-17 | `GET /imports/:id` + `GET /imports/:id/chapters` 进度查询 | MVP0-16 | 0.25d | 前端轮询用接口 200 通 | §5.1 §7.1 |
| MVP0-18 | import-worker：cleaning 阶段（BOM / 换行 / 空行压缩 / 全角空格） | MVP0-16 | 0.5d | 单测覆盖 5 个清洗规则；处理 demo.txt 输出可读 | §6.1 |
| MVP0-19 | import-worker：splitting 阶段（4 级章节切分规则 + 兜底滑窗 6000 字） | MVP0-18 | 1d | 单测覆盖中文章节标题 / Markdown 标题 / 空行短行 / 滑窗四种模式；切完后 `imported_chapters` 有行 | §5.1 §6.2 |
| MVP0-20 | Prompt 文件落盘：`prompts/import/summarize.txt`、`prompts/import/extract.txt`、`prompts/chapter/generate.txt` | MVP0-07 | 0.25d | 三个文件落盘；后端启动时 import 进内存常量 | §6.3 |
| MVP0-21 | import-worker：summarizing 阶段（每章串行调 LLM 摘要） | MVP0-19 MVP0-20 | 0.5d | 每章入 `imported_chapter.summary`；token 用量记 `generation_tasks` | §5.1 §6.3 |
| MVP0-22 | import-worker：extracting 阶段（每章串行抽取 + JSON 解析 + 1 次修正重试） | MVP0-21 | 1d | `extraction_candidates` 表入候选；JSON parse 失败时自动"只输出 JSON"重试 1 次 | §5.1 §6.3 §11 |
| MVP0-23 | embedding-worker：摘要 / 人物卡 / 世界观 embedding | MVP0-09 MVP0-22 | 0.75d | `vector_documents` 表入向量；ivfflat 检索能命中 | §5.1 §6.4 |
| MVP0-24 | import-worker：embedding 阶段串联 + 状态机收尾（status → reviewing） | MVP0-23 | 0.25d | 走完一遍 demo.txt 后 import_tasks.status='reviewing'、progress=100 | §5.1 |
| MVP0-25 | 审核接口：`GET /imports/:id/candidates?type=&status=`、`POST /candidates/:id/approve`、`POST /candidates/:id/reject` | MVP0-22 | 0.75d | approve 后写入 characters / world_settings 并触发 embedding；同名冲突返回 409 | §5.2 |
| MVP0-26 | 导入流水线集成测试：跑一遍 demo.txt 全链路（curl 脚本） | MVP0-24 MVP0-25 | 0.5d | 一个 shell 脚本：upload → 等到 reviewing → 列候选 → 接受若干 → 检查向量 | §10.1 |

**S2 出口标准**：手工跑 demo.txt 能在 ≤ 10 分钟内进入 reviewing 状态，候选数 ≥ 10，approve 后 `vector_documents` 多出对应行。

---

### S3：RAG + 章节生成 + 完结（7d）

| ID | 任务 | 依赖 | 估时 | 产出 | 设计依据 |
| -- | ---- | ---- | ---- | ---- | -------- |
| MVP0-27 | RAG service：4 路检索（CHARACTER / WORLD_SETTING / IMPORTED_CHAPTER_SUMMARY / CHAPTER_SUMMARY），cosine + ivfflat | MVP0-23 | 1d | `RagService.retrieve(novel, chapter)` 返回 4 路 top-k 候选；过滤条件 user_id + fandom_id/novel_id + source_type + embedding NOT NULL | §5.4 §6.4 |
| MVP0-28 | Prompt 拼装器：把 Novel / WritingStyle / Chapter / 4 路 RAG + 最近 3 章直拉 摘要塞入 generate prompt 模板 | MVP0-27 | 0.75d | 单测：空字段段落整体省略；非空字段正确拼接 | §6.5 |
| MVP0-29 | `POST /chapters/:id/generate` + generate-worker：创建 task → 调 LLM → 写回 chapter.content | MVP0-13 MVP0-28 | 1d | 任务从 pending → running → success；chapter.status → generated；token usage 写表 | §5.4 §6.5 |
| MVP0-30 | `GET /generation-tasks/:id`：前端轮询用 | MVP0-29 | 0.25d | 返回 status / result_text / error_message / token_usage | §7.1 |
| MVP0-31 | `POST /chapters/:id/complete`：投递 SUMMARY 任务 | MVP0-29 | 0.25d | task 入队 + chapter 锁定为正在完结 | §5.5 |
| MVP0-32 | generate-worker：CHAPTER_SUMMARY 摘要生成 + 写 chapter.summary + INSERT vector_documents | MVP0-31 MVP0-23 | 0.75d | chapter.status='final'；新 vector_document 可被下一章 RAG 命中 | §5.5 §6.3 |
| MVP0-33 | 离线 RAG 验证集（DoD #2 风险对冲）：用 demo.txt 准备一组 query → 期望命中 chapter，验证检索命中率 | MVP0-27 | 0.5d | 准备 10 个 query；命中率 ≥ 70% 视为通过；不通过则调 top-k / chunk 策略 | §11 |
| MVP0-34 | 章节生成端到端集成测试（脚本）：建 fandom → 导入 → 接受候选 → 建 novel → 建 ch1 → generate → complete → 建 ch2 → generate → 检查输出包含 ch1 关键词 | MVP0-32 | 1d | 脚本绿色；这是 DoD #2 的预演 | §10.1 |
| MVP0-35 | LLM 上下文溢出兜底：拼接 prompt 时硬上限（outline ≤ 4000、extraNotes ≤ 1000、人物字段 ≤ 800） | MVP0-28 | 0.25d | 单测覆盖超限截断；不接 token 预算裁剪算法 | §6.4 §11 |
| MVP0-36 | 失败兜底：worker 任意阶段抛错时 generation_tasks.status='failed'、error_message 写入；前端可重新触发（建新 task） | MVP0-29 | 0.25d | 故意把 LLM key 写错跑一遍，状态正确 + 错误信息可读 | §6.5 §11 |

**S3 出口标准**：用脚本走完"导入 → 审核 → 建小说 → 生成 ch1 → 完结 → 生成 ch2"全链路，ch2 输出包含 ch1 中提到的事件关键词（DoD #2 的内部预验收）。

---

### S4：前端最小可用（6d）

| ID | 任务 | 依赖 | 估时 | 产出 | 设计依据 |
| -- | ---- | ---- | ---- | ---- | -------- |
| MVP0-37 | API 客户端层：TanStack Query + axios 封装 + 类型从 packages/shared 共享 | MVP0-04 MVP0-14 | 0.5d | `useFandoms()` / `useNovel(id)` 等 hooks；统一错误处理弹 toast | §8.3 |
| MVP0-38 | 路由与布局：6 个路由 + 顶栏（仅 logo + demo 用户名）+ 左侧主导航 | MVP0-37 | 0.5d | 6 条路由通；空白 placeholder 页 | §8.1 |
| MVP0-39 | 工作台 `/` + 知识库列表 `/fandoms`：列表卡片 + 新建对话框 | MVP0-38 | 0.75d | 创建 Fandom 后跳详情；列表实时刷新 | §8.1 |
| MVP0-40 | Fandom 详情 `/fandoms/:id`：上传区（拖拽 + multipart） + 进度轮询条 | MVP0-39 MVP0-17 | 1d | 上传后看到进度阶段；处理中状态显示 stage；reviewing 后展开候选区 | §5.1 §8.1 |
| MVP0-41 | Fandom 详情：候选审核区（人物 / 世界观 / 事件三 tab）+ 已入库实体表 | MVP0-40 MVP0-25 | 1d | 接受 / 拒绝按钮工作；接受后实体表实时刷新 | §5.2 §8.1 |
| MVP0-42 | 我的小说 `/novels` + 新建对话框（title + fandomId 必填） | MVP0-39 MVP0-12 | 0.5d | 创建后跳小说空间 | §5.3 §8.1 |
| MVP0-43 | 小说空间 `/novels/:id`：章节列表 + 概要 + 新建章节 | MVP0-42 MVP0-13 | 0.5d | 列表 + 新建动作通 | §8.1 |
| MVP0-44 | 章节编辑器 `/novels/:id/chapters/:cid`：单栏布局（标题 / 大纲 / 出场人物多选 / 目标 / 额外要求 / 生成按钮 / 正文 textarea / 保存 / 完成本章） | MVP0-43 | 1.5d | 显式保存按钮、生成按钮、完成按钮全部接通；生成中 spinner；完成后弹窗 | §8.2 |
| MVP0-45 | 章节编辑器：轮询生成进度（refetchInterval 2000ms）→ 完成后覆盖正文 | MVP0-44 MVP0-30 | 0.5d | 生成任务从 pending → running → success 期间 UI 切状态；超 180s 告警 | §8.3 |

**S4 出口标准**：浏览器里完整走完"新建 fandom → 导入 → 审核 → 新建 novel → 新建 ch1 → 生成 → 完成 → 新建 ch2 → 生成"，不需要 curl。

---

### S5：验收与收尾（3d）

| ID | 任务 | 依赖 | 估时 | 产出 | 设计依据 |
| -- | ---- | ---- | ---- | ---- | -------- |
| MVP0-46 | 单测补齐到 ≥ 40%：核心模块覆盖优先（cleaning / splitting / RAG / prompt 拼装 / 状态机） | S2 S3 全部 | 1d | `pnpm test --coverage` 报告 ≥ 40% | §10 |
| MVP0-47 | 手工验收脚本走通（§10.1 十步）+ 录屏 / 截图归档 | MVP0-45 | 0.5d | 验收结果文档 `docs/mvp0-acceptance.md`：每步耗时、截图、出现的问题 | §10.1 |
| MVP0-48 | DoD #2 严格验证：换一个新的 fandom + 新 novel，跑完两章生成，肉眼比对 ch2 引用 ch1 的事件 | MVP0-47 | 0.5d | 至少 3 个真实测试样本；命中率作为质量基线归档 | §10 |
| MVP0-49 | 已知问题清单 + MVP-1 待办：把 MVP-0 跑通过程中发现的所有 TODO / FIXME / 性能问题 / UX 不顺手处归档 | MVP0-47 MVP0-48 | 0.25d | `docs/mvp0-followups.md`：分 P0 / P1 / 推迟到 MVP-1 | — |
| MVP0-50 | README 更新：从"代码尚未启动"改为"MVP-0 可运行"，加 quick start | MVP0-47 | 0.25d | `README.md` 含 docker-compose 启动 + pnpm dev + .env 模板 | — |
| MVP0-51 | （缓冲）应对前面任何任务超时 | — | 0.5d | — | — |

**S5 出口标准**：DoD 三条全部勾选 + `docs/mvp0-acceptance.md` 归档 + `docs/mvp0-followups.md` 形成 MVP-1 输入。

---

## 3. 关键依赖图（高层）

```
S0  docker / NestJS / Vite / Prisma / BullMQ / LLM
        │
        ▼
S1  schema → CRUD（Fandom → Novel → Chapter）
        │
        ▼
S2  import-worker（cleaning → splitting → summarizing → extracting → embedding）
                                  │
                              候选审核 API
        │                         │
        └─────────────┬───────────┘
                      ▼
S3  RAG service ── Prompt 拼装 ── generate-worker ── complete + 摘要回灌
                      │
                      ▼
              DoD #2 内部预演（脚本）
                      │
                      ▼
S4  前端 6 个页面，全部接通后端
                      │
                      ▼
S5  单测补齐 + 手工验收 + 文档收尾
```

**串行硬依赖**：S0 → S1 → S2 → S3。
**S4 可与 S3 末尾交叠 0.5–1d**：S3 出 API 后前端可先接已稳定的接口（Fandom / Novel CRUD / 导入 / 审核），最后再接生成接口。

---

## 4. 风险与缓冲

[0002-mvp0-design.md §11](0002-mvp0-design.md) 中所有风险都映射到本计划：

| 风险 | 对应任务 / 缓冲 |
| ---- | --------------- |
| LLM 上下文溢出导致大面积生成失败 | MVP0-35（硬上限） + 6d 总缓冲 |
| 章节切分错误污染知识库 | MVP0-19 单测覆盖 4 种切分模式 + MVP0-18 stage 检查点 |
| 抽取 JSON 解析失败 | MVP0-22 内置"只输出 JSON"重试 |
| **DoD #2 RAG 闭环不通过** | MVP0-33 离线验证集**前置到 S3 中段**，不到 S5 才发现 |
| LLM Provider 限流 / API key 失效 | MVP0-07 同时准备 OpenAI + DeepSeek 两套 key |
| 前后端联调阻塞 | API 类型走 `packages/shared`，MVP0-08 schema 完成后即可生成共享类型 |
| 估时整体不准 | MVP0-51 缓冲 0.5d；单任务超 1.5× 预估即停下重排 |

**总缓冲**：S5 内 0.5d 显式缓冲 + 6 周内有 2d 弹性（30d 容量 - 28d 任务）。如某周明显落后，**优先砍 MVP0-46（单测补齐）的范围**，把覆盖率从 ≥ 40% 退到 ≥ 30%。

---

## 5. 不在本计划内的事

明确 MVP-0 不做、不要随手开工的（出现冲动时回看 [§0.3](0002-mvp0-design.md) + [§12 下一期预告](0002-mvp0-design.md)）：

- 注册 / 登录 / JWT
- Repository 模式（保留 `user_id` 字段即可）
- 桌面端任何东西
- 自动保存 / 快照 / 冲突解决
- 向量一致性巡检 / 编辑级联
- 流式输出 / SSE
- Token 预算裁剪 / 配额 / 限流
- Prompt 模板版本管理 / registry.yaml
- Map-reduce 长摘要（直接走单次摘要，超长就靠 LLM 抛错）
- 安全 / 备份 / 生命周期 / 国际化 / Sentry / Prometheus
- TipTap（保留 textarea 就够）

每一项的归属期都已在 §0.3 标注，**不要在 MVP-0 阶段为了"顺手"提前做**——MVP-1 的设计文档已经把这些纳入。

---

## 6. 每周节奏建议（参考，可调）

| 周 | 主线 | 末周末自检 |
| -- | ---- | ---------- |
| W0 | S0 全部 + S1-08（schema） | docker-compose 起；schema 通过 review |
| W1 | S1 余下 + S2 导入 worker 前两阶段（cleaning / splitting） | curl 能创建 fandom / novel / chapter；splitting 能切分 demo.txt |
| W2 | S2 余下（摘要 / 抽取 / embedding / 审核） | 跑完一遍 demo.txt 到 reviewing；候选 ≥ 10 |
| W3 | S3 RAG + 生成 + 完结 + DoD #2 预演 | 脚本走通"ch1 生成 + ch2 引用 ch1" |
| W4 | S4 前端 6 页面 + 联调 | 浏览器里能完成手工验收脚本前 7 步 |
| W5 | S4 收尾 + S5 单测 + 验收脚本前半 | 手工脚本 10 步全部跑过一遍 |
| W6 | DoD 严格验证 + 收尾文档 + 缓冲 | 三条 DoD 全部勾选 |

---

## 7. 状态追踪

建议把本计划表头同步成 Issue / Project Board：

- 每个 `MVP0-XX` 一个 Issue，标题用任务名，body 链回本文件锚点。
- 看板列：Backlog / In Progress / In Review / Done。
- 每天日终更新 Issue 状态；每周末把 §6 自检清单贴到当周日报里。

如果未来切换到多人协作，把 §1 阶段表里的人天乘以并发度做粗排，并把 S2 / S3 / S4 之间的边界重新画出可并行区段（参考依赖图）。

---

文档结束。
