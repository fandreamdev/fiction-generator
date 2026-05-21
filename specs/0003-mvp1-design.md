# 同人小说创作应用 — MVP-1 增量设计文档（完整 MVP 体验）

- 文档编号：0003-mvp1-design
- 阶段：**MVP-1**（Week 6–12）
- 上游文档：[0002-mvp0-design.md](0002-mvp0-design.md)（MVP-0 基线） · [0001-design.md](0001-design.md)（全景设计）
- 下游文档：[0004-mvp2-design.md](0004-mvp2-design.md)（MVP-2 增量）
- 编写日期：2026-05-21

---

## 0. 本期目标与阅读方式

### 0.1 一句话目标

> **完整 MVP 体验**：邀请 < 50 个内测用户使用真实账号，每人能正常完成"导入原作 → 写 5 章以上同人小说"的端到端流程，跨 Web / Windows 桌面端互通。

### 0.2 阅读方式

**本文档只写增量**——前提条件是 MVP-0 已落地。每节都给出三类标签：

- 🆕 **新增**：MVP-0 不存在的新功能 / 新模块 / 新表 / 新字段
- 🔧 **修改**：MVP-0 已有实现的升级 / 替换
- 🗑 **废弃**：MVP-0 的临时方案被移除

如需阅读完整契约（数据字段、Prompt 全文、错误码细节），请回到 [0001-design.md](0001-design.md) 对应章节，本期保留同样的章节编号便于交叉对照。

### 0.3 本期范围一览

| 大类         | 增量内容                                                                  | 标签 |
| ------------ | ------------------------------------------------------------------------- | ---- |
| 账户         | 注册 / 登录 / 登出 / token 刷新                                           | 🆕   |
| 数据隔离     | Repository 模式 + 三道防线 + 越权审查 + 单元测试                          | 🆕   |
| 桌面端       | Tauri 2.0 壳 + WebView2 + 凭据存储 + 文件拖拽                             | 🆕   |
| 编辑器       | TipTap + 自动保存 + 冲突处理 + IndexedDB / 本地草稿恢复                   | 🔧   |
| 编辑器       | `chapter_snapshots` 表 + 快照恢复 UI                                      | 🆕   |
| 向量一致性   | 编辑 / 删除级联 + 一致性巡检任务                                          | 🆕   |
| 实体管理     | Character / WorldSetting / WritingStyle 手动 CRUD UI                      | 🆕   |
| 审核         | 编辑后接受 + 同名合并 + 批量操作 + 按章节/置信度排序                      | 🔧   |
| 导入         | markdown / 粘贴文本 + 并发处理（5 并发）+ SSE 进度                        | 🔧   |
| AI           | 长章节 map-reduce 摘要                                                    | 🆕   |
| AI           | Token 预算与裁剪算法 + RAG 审计                                           | 🆕   |
| AI           | Prompt 注入防护 + 输出过滤                                                | 🆕   |
| AI           | Prompt 模板版本管理（registry.yaml + .vN.txt）                            | 🆕   |
| AI           | 失败重试规则（网络 / rate-limit / overflow / JSON 修正）                  | 🆕   |
| AI           | 流式生成（SSE）                                                           | 🔧   |
| 任务         | GenerationTask 历史 UI + 失败重试按钮                                     | 🆕   |
| 创建向导     | 7 步引导（按 process.md）+ 可跳过 + 草稿                                  | 🆕   |
| 设置         | LLM Provider 配置（用户自带 Key）                                         | 🆕   |
| 可观测       | pino + Prometheus 指标 + 前端 Sentry                                      | 🆕   |

> ⚠️ **不包含在 MVP-1**（推迟到 MVP-2）：用户配额 / 全局限流、安全完整化（文件上传规则、对象存储签名、bcrypt 锁定）、数据生命周期 / 软删过期、备份、用户级导出、桌面端自动更新与签名、RLS、内容审核、合规文案。

---

## 1. 账户与多用户（🆕）

### 1.1 注册 / 登录

完整需求 / 验收 / API 沿用 [0001-design.md §2.3 US-01](0001-design.md#us-01-注册登录) + [§5.1](0001-design.md#51-注册与登录) + [§7.2 Auth 段](0001-design.md#72-端点清单含-5x-章节流程映射)。

实现要点：

| 项                | MVP-1 实现                                                       |
| ----------------- | ---------------------------------------------------------------- |
| 密码哈希          | bcrypt cost=12（cost 调高 + 失败锁定推迟到 MVP-2）               |
| Token             | JWT，access 2h + refresh 14d                                     |
| Refresh rotation  | **不做**（MVP-2 才做一次性 rotation + 黑名单）                   |
| 登录失败锁定      | **不做**（MVP-2 做）                                             |
| Token 黑名单      | **不做**（MVP-2 做）                                             |
| 邮箱验证 / 找回   | 不做（MVP-2 起接入邮件服务）                                     |
| 桌面端 Token 存储 | 见 §3.3                                                          |

### 1.2 数据隔离三道防线

完整方案见 [§4.5 多租户数据隔离与 RLS 预留](0001-design.md#45-多租户数据隔离与-rls-预留)，MVP-1 落实**前两道**：

| 层                  | MVP-1 状态 | 说明                                                |
| ------------------- | ---------- | --------------------------------------------------- |
| 路由层 AuthGuard    | ✅         | NestJS 全局 Guard 注入 `request.userId`             |
| Repository 层       | ✅         | 全面铺开 `BaseRepository<T>` + 父资源所有权校验     |
| 数据库 RLS          | ❌ MVP-2   | DDL / policy 不启用                                 |

#### 1.2.1 MVP-0 → MVP-1 迁移要点

- 把 MVP-0 中间件里写死的 `userId = demo` 替换为 JWT 解析。
- 把 MVP-0 业务代码里散落的 `prisma.*.findMany({...})` 全部改走 Repository。
- 加 ESLint 自定义规则：业务模块禁止直接 import prisma client（[§4.5.2](0001-design.md#452-repository-模式约定)）。
- demo user 保留作 e2e 测试种子数据。

#### 1.2.2 越权审查清单

按 [§4.5.3](0001-design.md#453-越权审查清单code-review-checklist) 在 PR 模板里加 checkbox，每次 review 必勾。

#### 1.2.3 自动化检测

按 [§4.5.5](0001-design.md#455-自动化检测) 在 CI 中加：

- 每个 Repository 必须有"A 用户访问 B 用户资源应得 404"的单元测试。
- 集成测试一组"双用户互访" e2e 用例覆盖所有 `GET /:id`。

---

## 2. 数据模型增量（🆕 / 🔧）

完整字段定义沿用 [§4.2](0001-design.md#42-表结构详设)，本节只列 MVP-0 → MVP-1 的差异。

### 2.1 新增表：`chapter_snapshots`（🆕）

完整定义见 [§5.8.5](0001-design.md#585-版本快照表-chapter_snapshots)。MVP-1 必建。

### 2.2 修改表：`chapters` 加列（🔧）

- 新增 `version int NOT NULL DEFAULT 0`，用于乐观锁（[§5.8.2](0001-design.md#582-版本号--乐观锁)）。
- 已有数据全量补 0，无破坏性。

### 2.3 修改表：`generation_tasks` 加列（🔧）

- `metadata jsonb` 字段在 MVP-0 已存在；MVP-1 起约定其中必须包含：
  - `prompt_template_version`（如 `"chapter.generate@v2"`）
  - `rag_audit`（[§6.7.3](0001-design.md#673-prompt-装配审计) 的结构）
  - `retries[]`（[§6.8.4](0001-design.md#684-失败重试规则)）

### 2.4 索引补全（🔧）

MVP-0 只建主键 / 外键 / 唯一键 + ivfflat。MVP-1 补建：

- 所有 list 接口涉及的 `(user_id, created_at desc)` 复合索引。
- `extraction_candidates` 的 `(fandom_id, entity_type, status)` 与 `name trgm`（同名合并搜索）。
- `vector_documents` 的 `(user_id, fandom_id, source_type)` 与 `(user_id, novel_id, source_type)`。

### 2.5 软删除字段启用（🔧）

MVP-0 已建 `deleted_at` 列但未使用。MVP-1 起：

- 所有 Repository 查询默认加 `WHERE deleted_at IS NULL`。
- 删除接口写 `deleted_at = now()`，**不**做硬删（硬删的生命周期管理推迟到 MVP-2）。

### 2.6 仍不创建（推迟到 MVP-2）

- `deletion_audit`
- Postgres RLS DDL

---

## 3. 桌面端（🆕）

完整需求与差异见 [§9 桌面端 vs Web 端差异](0001-design.md#9-桌面端-vs-web-端差异)。

### 3.1 共用前端

整个 React SPA、所有页面、所有 API 调用与 Web 完全共享，**不为桌面端分支**。运行时用 [§9.2](0001-design.md#92-桌面端tauri独有) 给的 runtime feature flag 判断：

```ts
const isDesktop = !!(window as any).__TAURI__;
```

### 3.2 Tauri 壳能力（MVP-1 必交付）

| 能力             | 实现                                          |
| ---------------- | --------------------------------------------- |
| WebView2 内嵌    | Tauri 2.0 默认                                |
| 凭据安全存储     | `tauri-plugin-stronghold` / Credential Manager |
| 文件拖拽导入     | Tauri 文件系统 API                            |
| 本地缓存 / 草稿  | `tauri-plugin-fs` 写应用数据目录              |
| 原生菜单 + 快捷键 | Tauri Menu API：Ctrl+S 保存、Ctrl+Enter 生成  |

**本期不做**：自动更新、代码签名、安装器 `.msi`、单实例锁、系统托盘（全部推迟到 MVP-2）。MVP-1 桌面端通过 `tauri dev` 或开发签名构建发给内测用户。

### 3.3 Token 存储

- 登录成功后调用 Tauri 命令 `secure_store.set("auth_token", ...)` 写 Windows Credential Manager。
- 重新启动时调 `secure_store.get` 回读，自动登录。
- 浏览器端走 `localStorage`（短期方案，MVP-2 评估是否换 httpOnly cookie）。

---

## 4. 章节编辑器升级（🔧 / 🆕）

完整方案见 [§5.8 自动保存、冲突处理与版本恢复](0001-design.md#58-自动保存冲突处理与版本恢复) + [§8.3 章节编辑器](0001-design.md#83-章节编辑器核心)。

### 4.1 替换正文 textarea → TipTap（🔧）

- MVP-0 的 `<textarea>` 仅作过渡。MVP-1 接入 TipTap（ProseMirror 基础），保留段落 / 加粗 / 斜体 / 引用 / 标题等最简集合。
- 编辑器内容存储仍是 markdown / 纯文本（TipTap 导出），不引入富文本结构字段。

### 4.2 自动保存（🆕）

按 [§5.8.1](0001-design.md#581-自动保存策略)：

- 触发：≥5s 间隔且有变更 / 累计 ≥200 字 / 失焦 / Ctrl+S。
- 请求：`PATCH /chapters/:id`，**仅发变更字段**（content / outline / title）。
- 节流：单章最多 1 个保存请求 in-flight。

### 4.3 版本号 + 乐观锁（🆕）

按 [§5.8.2](0001-design.md#582-版本号--乐观锁)：

- `chapters.version` 字段已通过 §2.2 加上。
- PATCH 请求体必带 `version: number`；后端 UPDATE 带 `WHERE version = $version`。
- 0 行更新 → `409 CONFLICT`，前端进入 §4.5 冲突流程。

### 4.4 本地草稿（🆕）

按 [§5.8.3](0001-design.md#583-本地草稿离线兜底)：

- Web：IndexedDB key=`chapter:{id}`，保存成功后清掉。
- 桌面：`%APPDATA%/fiction-studio/drafts/{novelId}/{chapterId}.json`。
- 重新进入章节时对比本地 vs 服务器 `updated_at`，提示恢复 / 丢弃。

### 4.5 冲突解决 UI（🆕）

按 [§5.8.4](0001-design.md#584-冲突解决-ui)：三栏对比 + 四个动作（保留我的 / 用服务器 / 手动合并 / 保存为新副本）。

### 4.6 快照表（🆕）

`chapter_snapshots`（[§5.8.5](0001-design.md#585-版本快照表-chapter_snapshots)）。生成时机：

| 时机                            | source                |
| ------------------------------- | --------------------- |
| 首次保存 AI 输出前              | `ai_generated`        |
| 单次保存 diff > 30% 字符        | `before_overwrite`    |
| 用户手动"保存快照"              | `manual`              |
| 完结本章                        | `manual`              |

保留策略：autosave / before_overwrite 滚动保留最近 20 条；manual / ai_generated 永久保留至章节硬删。

恢复接口（MVP-1 必交付）：

```
GET  /chapters/:id/snapshots
GET  /chapters/:id/snapshots/:sid
POST /chapters/:id/snapshots/:sid/restore
```

---

## 5. 向量一致性（🆕）

完整方案见 [§5.7 向量数据一致性](0001-design.md#57-向量数据一致性删除--编辑--完结)。MVP-0 因为不支持手动 CRUD 所以不需要处理；MVP-1 加了实体 CRUD 后**必须**实现。

### 5.1 触发矩阵

按 [§5.7.1](0001-design.md#571-触发矩阵) 实施。重点：

- Character / WorldSetting / WritingStyle 编辑涉及向量字段时 → 重新 embedding（旧向量保留至新向量就绪）。
- Character / WorldSetting 软删时 → **硬删**对应 vector_document（[§5.7.3](0001-design.md#573-软删除-vs-硬删除) 的核心决策）。
- Chapter 软删 / 回退为 draft → 硬删 CHAPTER_SUMMARY 向量。

### 5.2 事务保证

按 [§5.7.2](0001-design.md#572-事务一致性保证)：

- 业务 + 向量同库 → 同 PostgreSQL 事务提交。
- embedding 异步任务：事务内插入 `vector_documents` 占位行（embedding NULL，metadata.status=pending），事务外 enqueue embedding 任务回填。
- RAG 检索强制 `WHERE embedding IS NOT NULL`，避免脏读。
- BullMQ jobId 去重：同一 source_id 同时只允许一个 embedding 任务。

### 5.3 一致性巡检任务（🆕）

按 [§5.7.4](0001-design.md#574-一致性巡检任务)，新增每日 worker `vector-consistency-check`：

1. 找出向量表中 `source_id` 在源表已删除（含软删）的行 → 告警并清理。
2. 找出源表有但向量表缺失的实体 → 重新 enqueue embedding。
3. 同一 source_id 多份向量 → 保留最新删除其余。

---

## 6. 实体手动 CRUD（🆕）

MVP-0 只允许 AI 抽取 + 审核入库。MVP-1 加完整 CRUD UI。

### 6.1 Character / WorldSetting / WritingStyle

按 [§2.3 US-09](0001-design.md#us-09-人物--世界观管理) + [§4.2.7 / 4.2.8 / 4.2.11](0001-design.md#427-characters)。

- 列表 + 搜索 + 分类筛选。
- 表单字段沿用数据库结构。
- 删除二次确认；删除后触发 §5 向量一致性清理。
- 编辑后自动更新对应向量。

### 6.2 审核侧增强（🔧）

按 [§5.3](0001-design.md#53-候选实体审核)：

- 加"编辑后接受"表单（MVP-0 只有接受 / 拒绝）。
- 加"合并到已有实体"（按 name trgm 模糊搜索目标，前端选择，后端写 target_entity_id 不新建）。
- 候选列表加按章节 / 置信度排序。
- 批量操作：选中多条 → 一次性接受 / 拒绝。

---

## 7. 导入流水线升级（🔧）

完整流程见 [0001-design.md §5.2](0001-design.md#52-创建-fandom--导入文本异步流水线)，MVP-1 在 MVP-0 基础上提升：

| 项                | MVP-0           | MVP-1                                       |
| ----------------- | --------------- | ------------------------------------------- |
| 支持文件类型      | txt             | txt + markdown + **粘贴文本**               |
| 处理方式          | 顺序            | 章节级 5 并发 + Provider TPS 限流           |
| 进度反馈          | 轮询            | SSE：`GET /imports/:id/stream`              |
| 失败处理          | 整任务 failed   | 章节级失败可重试（不消耗用户配额）          |
| 长章节摘要        | 一次性          | Map-reduce（见 §8.2）                       |

---

## 8. AI 能力增量

### 8.1 Token 预算与 RAG 审计（🆕）

按 [§6.7](0001-design.md#67-rag-来源优先级token-预算与审计) 全章实施：

- L1-L4 分层检索 + 预算分配。
- 预算反推公式：`input_budget = total_budget - output_budget - safety_margin`。
- 超限按 L4 → L3 从低相似度往上裁剪。
- 每次任务在 `generation_tasks.metadata.rag_audit` 记录被检索 / 被裁剪的条目。

### 8.2 长章节 Map-Reduce 摘要（🆕）

按 [§6.9](0001-design.md#69-长章节摘要分块策略)：

| 长度区间 (token) | 处理                               |
| ---------------- | ---------------------------------- |
| ≤ 6000           | 直接一次性摘要（同 MVP-0）         |
| 6000 – 24000     | 切 3–8 块 map-reduce               |
| > 24000          | 切 ≥ 8 块 + 二级 reduce            |

MVP-1 只 embedding final summary 不 embedding sub-summary（控成本）。

### 8.3 Prompt 注入防护（🆕）

按 [§6.10](0001-design.md#610-prompt-注入防护与-llm-输出安全) 全章：

- 输入侧：结构化 `<user_data>` 分区、转义、字段长度上限、导入文本注入模式预警。
- 输出侧：模板回显检测、跨租户 UUID 扫描、长度异常标记、模型输出不直接二次执行。
- 候选审核屏障：候选字段含可疑指令时高亮 + 预填"建议拒绝"。

**内容审核**（[§6.10.3.4](0001-design.md#6103-输出侧防护)）在 MVP-1 仅做最轻度的关键词过滤（child / hate 等高危类别），完整接入 Provider Moderation 推迟到 MVP-2。

### 8.4 Prompt 模板版本管理（🆕）

按 [§6.11](0001-design.md#611-prompt-模板版本管理)：

- 文件组织 `prompts/{module}/{name}.vN.txt` + `prompts/registry.yaml`。
- 旧版本永久保留，变更走"新增 .vN.txt + 改 registry + PR"，禁止覆盖。
- 任务记录 `prompt_template_version`。
- 灰度环境变量 `PROMPT_GRAYSCALE_RATIO` + `PROMPT_OVERRIDE_*`。

### 8.5 失败重试规则（🆕）

按 [§6.8.4](0001-design.md#684-失败重试规则) 全面落地：

| 失败类型          | 重试 | 退避                | 计费               |
| ----------------- | ---- | ------------------- | ------------------ |
| 网络瞬断 / 5xx    | 2 次 | 5s, 15s             | 仅成功调用计费     |
| 429 rate limit    | 3 次 | 10/30/90s + jitter  | 不计费             |
| 内容审核拒绝      | 否   | —                   | 不计费             |
| Prompt 超长溢出   | 自动裁剪后重试 1 次 | 即时         | 计费               |
| JSON 解析失败     | "修正调用"重试 1 次 | 即时         | 计费               |
| 用户取消          | 否   | —                   | 已发送 prompt 计费 |

所有重试历史进 `generation_tasks.metadata.retries[]`。

### 8.6 流式生成（🔧）

MVP-0 非流式 → MVP-1 全量改 SSE：

- 后端：worker 边收 LLM token 边推 SSE，同时累加写 `generation_tasks.result_text`。
- 前端：`GET /chapters/:id/generate/stream` 订阅，编辑器右侧底部小窗实时显示，点"应用到正文"才覆盖 `chapter.content`。
- 失败部分落库：可恢复展示已生成片段。

### 8.7 配额与限流（部分前置）

**MVP-1 仅做内部并发限制**（避免邀测用户互相影响）：

- BullMQ generate-queue 全局 rate-limit。
- 单用户并发 ≤ 3 个 AI 任务，超出排队。

**用户级配额 / 软硬上限 / Redis 计数器**（[§6.8.2](0001-design.md#682-用户配额每用户级)）推迟到 MVP-2。

---

## 9. API 增量

### 9.1 新增端点

| 模块      | 方法      | 路径                          | 关联章节                                                  |
| --------- | --------- | ----------------------------- | --------------------------------------------------------- |
| Auth      | POST      | /auth/register                | [§5.1](0001-design.md#51-注册与登录)                       |
| Auth      | POST      | /auth/login                   | 同上                                                      |
| Auth      | POST      | /auth/refresh                 | 同上                                                      |
| Auth      | POST      | /auth/logout                  | 同上                                                      |
| Fandom    | PUT       | /fandoms/:id                  | 编辑                                                      |
| Import    | GET       | /imports/:id/stream           | SSE 进度推送                                              |
| Candidate | POST      | /candidates/:id/merge         | 合并到已有实体                                            |
| Character | GET / POST     | /fandoms/:id/characters      | 列表 + 新建                                               |
| Character | PUT / DELETE   | /characters/:id              | 编辑 + 软删                                               |
| World     | GET / POST     | /fandoms/:id/world-settings  | 列表 + 新建                                               |
| World     | PUT / DELETE   | /world-settings/:id          | 编辑 + 软删                                               |
| Style     | GET / POST     | /novels/:id/styles           | 列表 + 新建                                               |
| Style     | PUT       | /styles/:id                   | 编辑                                                      |
| Volume    | POST      | /novels/:id/volumes           | 新建分卷                                                  |
| Volume    | PUT       | /volumes/:id                  | 编辑                                                      |
| Novel     | PUT       | /novels/:id                   | 编辑                                                      |
| Chapter   | PATCH     | /chapters/:id                 | **变更字段 + 乐观锁**（[§5.8.2](0001-design.md#582-版本号--乐观锁)） |
| Chapter   | GET       | /chapters/:id/generate/stream | SSE 生成流                                                |
| Chapter   | POST      | /chapters/:id/summarize       | 仅生成摘要（不完结）                                      |
| Snapshot  | GET       | /chapters/:id/snapshots       | 快照列表                                                  |
| Snapshot  | GET       | /chapters/:id/snapshots/:sid  | 单快照正文                                                |
| Snapshot  | POST      | /chapters/:id/snapshots/:sid/restore | 还原                                              |
| Task      | GET       | /generation-tasks             | 任务列表（按 novel / chapter / status 过滤）              |
| Task      | POST      | /generation-tasks/:id/retry   | 重试                                                      |
| Settings  | GET / PUT | /settings/llm                 | LLM Provider 配置                                         |

### 9.2 修改端点

- `PUT /chapters/:id`（MVP-0 全量）→ MVP-1 改为 `PATCH /chapters/:id` 增量（带 version）。
- `POST /chapters/:id/generate`（MVP-0 返回 taskId 后客户端轮询）→ MVP-1 后续可订阅 `GET /chapters/:id/generate/stream`。

### 9.3 新增错误码

| code             | HTTP | 触发场景                                          |
| ---------------- | ---- | ------------------------------------------------- |
| UNAUTHORIZED     | 401  | token 缺失 / 失效                                 |
| FORBIDDEN        | 403  | 越权访问                                          |
| CONFLICT         | 409  | 乐观锁版本冲突（章节并发保存）                    |
| LLM_RATE_LIMITED | 429  | Provider 限流，自动重试用尽后返回                  |

---

## 10. 前端增量

完整页面清单见 [§8.2](0001-design.md#82-页面清单)。MVP-1 新增 / 升级：

### 10.1 新增页面（🆕）

| 路由                  | 名称       | 关联章节                                                   |
| --------------------- | ---------- | ---------------------------------------------------------- |
| `/login` `/register`  | 登录注册   | [§5.1](0001-design.md#51-注册与登录)                        |
| `/novels/new`         | 创建向导   | [§5.4 入口 A](0001-design.md#入口-a引导式向导按-processmd-7-步) |
| `/imports/:id/review` | 导入审核   | 四列：候选人物 / 候选世界观 / 候选事件 / 章节摘要          |
| `/tasks`              | 生成历史   | 表格 + 详情抽屉                                            |
| `/settings`           | 设置       | LLM Provider 配置 + 个人资料                               |

### 10.2 升级页面（🔧）

- `/fandoms/:id`：MVP-0 单页 → MVP-1 Tabs（概览 / 导入章节 / 人物 / 世界观 / 导入任务）。
- `/novels/:id`：单页 → Tabs（章节 / 人物 / 世界观 / 风格 / 设置）。
- `/novels/:id/chapters/:cid`：单栏 textarea → **三栏 TipTap 编辑器**（章节列表 / 编辑区 / AI 助手 + 流式输出小窗）。

### 10.3 创建向导（🆕）

按 [§5.4 入口 A](0001-design.md#入口-a引导式向导按-processmd-7-步)：

- 7 步：标题 → 核心创意 → 题材类型 → 世界观 → 人物 → 主线主题 → 大纲。
- 提交时事务创建 Novel + Volume + WritingStyle + 关联实体。
- 中途存草稿：Web 写 sessionStorage，桌面写本地配置文件。

---

## 11. 可观测性（🆕）

完整规划见 [§10.3](0001-design.md#103-可观测性)。MVP-1 落地：

| 项                  | 实施                                                                                                |
| ------------------- | --------------------------------------------------------------------------------------------------- |
| 后端日志            | 替换 console → pino → JSON 结构化输出。必填字段：`time / level / requestId / userId / module / msg` |
| 队列 Dashboard      | BullMQ Dashboard 加 Basic Auth                                                                      |
| Metrics             | Prometheus 暴露 `/metrics`，关键指标见 [§10.3.2](0001-design.md#1032-任务与队列)                    |
| 前端 + 桌面端 Sentry | 一个项目两个 environment：`web` / `desktop`。错误 100%、performance 10%。Release 关联 sourcemap     |
| LLM 调用审计        | `generation_tasks` 表 + Prometheus `llm_call_duration_seconds` / `llm_tokens_total`                 |

**敏感数据脱敏**（[§10.3.5](0001-design.md#1035-敏感数据脱敏规则)）规则在 MVP-1 完整落地（即便配额还没上）：日志 / Sentry 上报前必须过 redactor。

---

## 12. 仍不包含（推迟到 MVP-2）

明确不在 MVP-1 范围、但 Backlog 已规划：

- **用户配额**：每日 / 每月软硬上限 + Redis 计数器 + 超限拒绝（[§6.8.2](0001-design.md#682-用户配额每用户级)）。
- **完整文件上传规则**：MIME / 扩展名 / 编码 / 病毒扫描 / 上传频率 / 直传预签名（[§10.2.2](0001-design.md#1022-文件上传)）。
- **对象存储私有化**：bucket private + 短期签名 URL + 路径规约（[§10.2.3](0001-design.md#1023-对象存储)）。
- **bcrypt 失败锁定 + refresh rotation + token 黑名单**（[§10.2.1](0001-design.md#1021-鉴权与隔离)）。
- **CORS + CSP + HSTS** 收紧（[§10.2.4](0001-design.md#1024-输出--通信)）。
- **数据生命周期 / 软删除保留期 / 硬删任务 / deletion_audit**（[§10.6](0001-design.md#106-数据生命周期与删除策略)）。
- **账号注销流程**（[§10.6.2](0001-design.md#1062-用户主动删除账号注销)）。
- **备份**：pg_dump 全量 + WAL 归档（[§10.4](0001-design.md#104-备份与导出)）。
- **用户级导出 F-91**：schemaVersion + zip 打包（[§14.2](0001-design.md#142-用户数据导出-json-结构含-schemaversion)）。
- **桌面端自动更新 + 代码签名 + .msi 安装器 + 单实例锁**（[§9.2](0001-design.md#92-桌面端tauri独有)）。
- **Postgres RLS**（[§4.5.4](0001-design.md#454-postgres-rls-预案v11-启用)）。
- **i18n 基础设施 / 合规文案 / 后台管理**。
- **完整内容审核**（Provider Moderation 接入）。

---

## 13. 完成定义（DoD）

沿用 [§12.3 MVP-1 完成定义](0001-design.md#123-mvp-1完整-mvp-体验week-612)：

1. 满足 [§13 全部 10 条验收场景](0001-design.md#13-验收标准mvp-总验收)。
2. 邀请用户实测 7 天，能完成 ≥ 1 部 5 章以上同人小说。
3. 单测覆盖核心 service ≥ 60%；E2E 覆盖关键流程。
4. 越权审查 CI 用例（A 用户访问 B 用户资源 → 404）100% 通过。

---

## 14. 风险与对策（MVP-1 阶段重点）

| 风险                              | 影响                       | 对策                                                  |
| --------------------------------- | -------------------------- | ----------------------------------------------------- |
| Repository 模式改造遗漏          | 数据隔离 bug → 越权事故    | ESLint 规则 + PR checklist + 双用户互访自动化测试      |
| 桌面端 WebView2 缺失              | 装机失败                   | Tauri 安装器内置 bootstrapper                         |
| 长篇连贯性退化（30 章后忘前情）   | 用户体验断崖               | RAG top-k 适度调高 + 卷级摘要在 v2 规划               |
| Prompt 注入造成知识库污染         | 后续生成被劫持              | §8.3 输入侧防护 + 候选审核屏障                        |
| Provider API 不稳                 | 生成大面积失败             | LLM 客户端预留 Provider 抽象层（MVP-1 接入但只用 1 家） |
| Sentry / Prometheus 配置不当泄漏 PII | 合规风险                  | redactor 强制在所有上报路径前置 + CI 检测 hook         |

完整风险矩阵见 [§11](0001-design.md#11-风险权衡与缓解)。

---

## 15. 下一期预告

[0004-mvp2-design.md](0004-mvp2-design.md) 将在此基础上把"内测产品"转化为"对外开放注册的准生产产品"：

- 完整安全（上传规则、对象存储签名、bcrypt 锁定、refresh rotation）
- 配额与限流（每日 / 每月软硬上限）
- 数据生命周期（软删过期、硬删 worker、账号注销、deletion_audit）
- 备份与用户级导出（schemaVersion）
- 桌面端自动更新 / 签名 / 安装器
- Postgres RLS 启用
- i18n / 合规文案 / 后台管理

---

文档结束。
