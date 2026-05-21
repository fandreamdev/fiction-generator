# 同人小说创作应用 — MVP-2 增量设计文档（准生产对外）

- 文档编号：0004-mvp2-design
- 阶段：**MVP-2**（Week 12–18）
- 上游文档：[0003-mvp1-design.md](0003-mvp1-design.md)（MVP-1 基线）· [0002-mvp0-design.md](0002-mvp0-design.md) · [0001-design.md](0001-design.md)
- 编写日期：2026-05-21

---

## 0. 本期目标与阅读方式

### 0.1 一句话目标

> **去掉"内测"标签，可对外开放注册**：完成合规与可运营所需的安全、配额、备份、生命周期、签名分发等全部保障。

### 0.2 阅读方式

本文档**仍是增量 diff**——前提是 MVP-1 已落地（多用户、桌面端壳、完整 RAG、自动保存 / 快照 / 向量一致性、模板版本管理、Sentry / Prometheus 等）。每节用同样的标签体系：

- 🆕 **新增**：MVP-0 / MVP-1 完全没有的能力
- 🔧 **修改**：MVP-1 的轻量版本升级到生产版本
- 🚀 **启用**：MVP-1 已部分预留 / 设计但未启用的能力，本期正式启用

### 0.3 本期范围一览

| 大类           | 增量内容                                                          | 标签 |
| -------------- | ----------------------------------------------------------------- | ---- |
| 安全：鉴权     | bcrypt 失败锁定 + refresh rotation + token 黑名单                 | 🔧   |
| 安全：上传     | 完整 MIME / 扩展名 / 大小 / 编码 / 路径穿越 / 上传频率            | 🔧   |
| 安全：存储     | 对象存储私有化 + 短期签名 URL + 路径规约 + 加密                   | 🔧   |
| 安全：传输     | CORS 收紧 + HSTS + CSP（Web 端）                                  | 🔧   |
| 安全：审核     | LLM 输出 Provider Moderation 接入 + 可配置敏感度                  | 🔧   |
| 配额           | 用户每日 / 每月软硬上限 + Redis 计数器 + 超限处理                 | 🆕   |
| 配额           | 用量看板 + 计费基础                                               | 🆕   |
| 生命周期       | 软删除保留期 + HardDeleteJob + deletion_audit                      | 🆕   |
| 生命周期       | 账号注销流程（含 30 天缓冲期）                                    | 🆕   |
| 生命周期       | 上传文件归档 / 任务 prompt_text 裁剪                              | 🆕   |
| 备份           | pg_dump 每日全量 + WAL 归档 + 恢复演练                            | 🆕   |
| 导出           | 用户级导出 F-91：schemaVersion + JSON + zip + markdown 章节       | 🆕   |
| 桌面端         | 自动更新 + 代码签名 + .msi 安装器 + 单实例锁 + 原生菜单           | 🔧   |
| RLS            | Postgres RLS DDL + 连接池 `SET LOCAL`                             | 🚀   |
| 性能           | 全部 [§10.1](0001-design.md#101-性能分阶段指标) P95 指标达成     | 🔧   |
| 性能           | 负载测试 ≥ 50 RPS                                                 | 🆕   |
| 国际化         | i18n 基础设施（即便 MVP 只发中文）                                | 🆕   |
| 合规           | 隐私政策 / 用户协议 / 数据导出 / 注销路径                         | 🆕   |
| 运营           | 后台管理：用户列表 / 配额调整 / 反馈处理                          | 🆕   |

---

## 1. 安全完整化（🔧）

### 1.1 鉴权强化（🔧）

完整规则见 [§10.2.1 鉴权与隔离](0001-design.md#1021-鉴权与隔离)。MVP-1 → MVP-2 差异：

| 项                  | MVP-1                  | MVP-2                                                  |
| ------------------- | ---------------------- | ------------------------------------------------------ |
| 密码哈希            | bcrypt cost=12         | 同；明文返回拦截在 DTO 层硬约束                        |
| 登录失败锁定        | ❌                     | ✅ > 5 次 / 15 min 临时锁定（Redis key + TTL）         |
| Refresh 一次性 rotation | ❌                | ✅ 每次 refresh 颁发新对 + 旧 refresh 入黑名单         |
| Token 黑名单        | ❌                     | ✅ 登出 / 注销时入 Redis 黑名单，TTL = token 剩余有效期 |
| 桌面端 devtools     | 默认开启               | ✅ release 构建强制禁用                                |
| Tauri allowlist     | 宽松                   | ✅ 仅放行必需的 API，禁用 shell / exec / network 自由调用 |
| 安装包签名          | ❌                     | ✅ 代码签名证书（与 §6 自动更新一并）                  |

### 1.2 文件上传规则（🔧）

完整规则见 [§10.2.2 文件上传](0001-design.md#1022-文件上传)。MVP-1 仅做最基本校验；MVP-2 全量实施：

| 控制             | MVP-2 规则                                                                 |
| ---------------- | -------------------------------------------------------------------------- |
| MIME 白名单      | `text/plain`、`text/markdown`、`application/octet-stream`（按扩展名再判） |
| 扩展名白名单     | `.txt`、`.md`                                                              |
| 文件大小         | ≤ 5 MB（可配置）                                                          |
| 文件名清洗       | 仅保留 `[A-Za-z0-9一-龥._-]`，其他替换 `_`；防 `../` 路径穿越              |
| 编码嗅探         | 强制 UTF-8 / GBK；非文本字节比例 > 5% 拒绝                                 |
| 上传频率         | 单用户 ≤ 20 次 / 小时                                                      |
| 病毒扫描         | MVP-2 仍**不接 ClamAV**（推迟到正式 1.x）；规则与 hook 留好                |
| 拒绝示例         | exe / zip / pdf 等直接 415                                                 |

**直传策略**：迁移到 §1.3 描述的预签名 URL 模式。MVP-1 还在走 `multipart` 通过后端中转，MVP-2 起浏览器直传 MinIO / S3。

### 1.3 对象存储私有化（🔧）

完整规则见 [§10.2.3 对象存储](0001-design.md#1023-对象存储)：

- Bucket private，禁止公网读。
- 路径规约：`uploads/{userId}/{fandomId}/{yyyy-mm}/{uuid}.txt`。
- 上传流程：
  1. 前端 `POST /imports/presign` 取预签名 PUT URL。
  2. 浏览器 / 桌面直传 MinIO / S3。
  3. 前端 `POST /fandoms/:id/imports` 提交 `objectKey`。
  4. 后端校验 objectKey 的 userId 前缀与 token 中的用户匹配 + 校验 size。
- 服务端读：每次签短期 URL（≤ 5 分钟）。
- 服务端加密：S3 SSE-S3 / MinIO server-side encryption。MVP-2 **不上** SSE-KMS（推迟到 v1.x）。
- Bucket policy 强制 `userId` 前缀匹配 token 用户。

### 1.4 传输 / 通信（🔧）

完整规则见 [§10.2.4 输出 / 通信](0001-design.md#1024-输出--通信)：

| 项     | MVP-2 实施                                                                |
| ------ | ------------------------------------------------------------------------- |
| HTTPS  | 全站；HSTS preload 域                                                     |
| CORS   | 仅允许已注册的 Web 端 origin；桌面端走 Tauri IPC 不走 CORS                |
| CSP    | Web 端 `default-src 'self'`，禁止 inline script，显式允许图片 / 字体域    |
| LLM 输出过滤 | 见 §1.5                                                                |

### 1.5 LLM 输出审核（🔧）

完整规则见 [§6.10.3](0001-design.md#6103-输出侧防护)。MVP-1 仅做关键词过滤；MVP-2 升级：

- 接入 Provider 自带 Moderation（OpenAI Moderation 等）。
- 默认开启低敏感度规则（child / hate / extreme violence 等高危），用户可在设置中调整。
- 模板回显检测：连续 ≥ 3 个系统模板专有标签 → 判模板泄漏，重试 1 次 + 上报告警。
- 跨租户 UUID / 邮箱扫描 → 命中脱敏为 `[REDACTED]`。
- 长度异常：响应 > `wordTarget * 2` 或 < `wordTarget * 0.3` → `quality_warning` 标记，不阻断。

### 1.6 敏感数据脱敏（🔧）

MVP-1 已实施 redactor。MVP-2 起在以下新路径强制接入：

- 配额超限告警邮件 / 后台运营查询 / 用户主动注销审计日志。
- 完整规则表见 [§10.3.5](0001-design.md#1035-敏感数据脱敏规则)。

---

## 2. 配额与限流（🆕）

完整方案见 [§6.8 AI 调用：成本、配额、限流与失败重试](0001-design.md#68-ai-调用成本配额限流与失败重试)。MVP-1 已做内部并发限制；MVP-2 起对**每个用户**做配额管理。

### 2.1 配额维度（默认值，可后台调整）

| 维度                 | 软上限 | 硬上限 | 超限处理                                                |
| -------------------- | ------ | ------ | ------------------------------------------------------- |
| 章节生成次数 / 日    | 30     | 60     | 软：UI 黄条；硬：`429 QUOTA_EXCEEDED`                  |
| 章节生成次数 / 月    | 600    | 1200   | 同上                                                    |
| 导入字数 / 日        | 50 万  | 200 万 | 同上                                                    |
| Embedding token / 月 | 500 万 | 2000 万 | 同上                                                   |
| LLM 总 token / 月    | 500 万 | 2000 万 | 同上                                                   |

### 2.2 实现

- Redis 计数器 key 模式：`quota:{userId}:{metric}:{day|month}`，TTL 设到对应周期结束。
- 用户**自带 API Key** 模式（已在 MVP-1 §1 LLM Provider 配置启用）下，平台只**统计**配额、**不限制**——用户付自己的钱不该被限。
- 拒绝时返回错误码：

  ```json
  { "error": { "code": "QUOTA_EXCEEDED", "message": "...", "details": { "metric": "chapter_generate_daily", "reset_at": "..." } } }
  ```

### 2.3 用量看板

- 用户侧：`/settings/usage` 页面，展示日 / 月用量条形图 + 重置时间。
- 后台侧：见 §10 后台管理。

### 2.4 计费基础（如开商业化）

- `generation_tasks.token_usage` + 计费表 `billing_records`：MVP-2 仅建表 + 写入，UI / 支付链路不在本期。
- 表结构：`user_id, period_yyyymm, model, prompt_tokens, completion_tokens, embedding_tokens, calculated_at`。
- 每日凌晨任务从 `generation_tasks` 聚合到 `billing_records`。

---

## 3. 数据生命周期（🆕）

完整方案见 [§10.6 数据生命周期与删除策略](0001-design.md#106-数据生命周期与删除策略)。

### 3.1 软删除保留期

| 实体                                          | 保留期     | 到期处理                                   |
| --------------------------------------------- | ---------- | ------------------------------------------ |
| Character / WorldSetting / WritingStyle       | 30 天      | 硬删 + 级联硬删向量                        |
| Chapter                                       | 60 天      | 硬删 + 删快照 + 删向量                     |
| Novel                                         | 90 天      | 硬删 + 级联所有归属资源                    |
| Fandom                                        | 90 天      | 硬删 + 级联归属资源 + 删上传文件           |
| ImportTask + ImportedChapter                  | 完成 90 天 | 硬删原文；摘要保留（已审核入库的不受影响） |

实现：每日定时任务扫描 `deleted_at + interval < now()` 的行入 HardDeleteJob。

### 3.2 用户主动删除（账号注销）

按 [§10.6.2](0001-design.md#1062-用户主动删除账号注销)：

```
DELETE /account（要求二次密码确认）
  ↓
即时：users.deleted_at = now()
      所有子资源软删
      所有 access / refresh token 入黑名单
  ↓
30 天缓冲期内：可联系客服反向操作恢复
  ↓
T+30 天：后台任务硬删用户全部业务数据 + 对象存储文件
         Sentry deletion API 移除 userId 关联
         日志归档保留 180 天后销毁
```

注销路径必须从前端 `/settings/account` 一路可达，不允许走"隐藏入口"——合规要求。

### 3.3 临时数据保留

按 [§10.6.3](0001-design.md#1063-临时数据保留)：

| 数据                                            | 保留期                                   |
| ----------------------------------------------- | ---------------------------------------- |
| `generation_tasks.prompt_text` / `result_text`  | 30 天后裁剪为 hash + 摘要元信息          |
| `chapter_snapshots`（autosave / before_overwrite） | 滚动保留最近 20 条                    |
| Redis 配额计数                                  | 自然到期                                 |
| Refresh token 黑名单                            | TTL = token 剩余有效期                   |
| 上传原文（已成功导入）                          | 30 天后归档；90 天后删除（除非用户置顶） |
| 上传失败文件                                    | 24 小时后清理                            |

### 3.4 HardDeleteJob + deletion_audit（🆕 表）

按 [§10.6.4 物理删除清单](0001-design.md#1064-物理删除清单)：

- 统一的 `HardDeleteJob`，幂等可重试，覆盖：DB 级联 / 向量 / 对象存储 / Redis 缓存 / 日志 PII / Sentry。
- `deletion_audit` 表（[§14.6](0001-design.md#146-删除审计与生命周期记录-schema)）：保留 1 年，记录每次硬删的目标、范围摘要、执行结果。

---

## 4. 备份与恢复（🆕）

按 [§10.4 备份与导出](0001-design.md#104-备份与导出)：

| 项               | MVP-2 实施                                                              |
| ---------------- | ----------------------------------------------------------------------- |
| DB 全量备份      | pg_dump 每日一次，加密落异地存储                                        |
| DB 增量          | WAL 归档，保留 30 天                                                    |
| 全量保留         | 7 天                                                                    |
| 对象存储         | bucket 启用版本控制；删除走 §3 生命周期                                 |
| 灰度恢复演练     | 每月一次，从备份恢复整库到 staging，验证 ≤ 2 小时（DoD 指标）           |

恢复演练 SOP 文档化，演练后产出报告归档。

---

## 5. 用户级数据导出 F-91（🆕）

完整方案见 [§14.2 用户数据导出 JSON 结构](0001-design.md#142-用户数据导出-json-结构含-schemaversion)。

### 5.1 导出内容

- `export.json`：含 schemaVersion 的完整结构（用户 / fandoms / characters / world_settings / novels / volumes / chapters / writing_styles / generationTasks 元信息）。
- `chapters/{novelId}/{chapterNo}.md`：每章正文 markdown（便于人类阅读）。
- `attachments/`：用户选择是否包含原始上传 txt。
- 整体 zip：`fictionstudio-export-{userId}-{yyyyMMdd-HHmmss}.zip`，UTF-8 + LF。

### 5.2 schemaVersion 约定

按 [§14.2.2](0001-design.md#1422-schemaversion-约定)：

- 遵循 `MAJOR.MINOR.PATCH`。
- 导入时按版本兼容性策略处理。
- 维护 `docs/export-schema-CHANGELOG.md` 记录每次字段变更。

MVP-2 首版 `schemaVersion = "1.0.0"`。

### 5.3 接口

```
POST /account/exports           创建导出任务（异步）
GET  /account/exports           历史列表
GET  /account/exports/:id       状态 + 下载链接（短期签名 URL）
```

导出任务走 BullMQ，限速：单用户 ≤ 1 次进行中 + 每日 ≤ 3 次。

---

## 6. 桌面端生产化（🔧）

完整规划见 [§9.2 桌面端独有能力](0001-design.md#92-桌面端tauri独有) + [§9.5 打包与分发](0001-design.md#95-打包与分发)。

### 6.1 MVP-1 → MVP-2 差异

| 能力             | MVP-1                | MVP-2                                                     |
| ---------------- | -------------------- | --------------------------------------------------------- |
| 凭据存储         | ✅                   | ✅                                                        |
| 文件拖拽         | ✅                   | ✅                                                        |
| 本地草稿         | ✅                   | ✅                                                        |
| 自动更新         | ❌                   | ✅ Tauri Updater + 签名 manifest                          |
| 代码签名         | ❌                   | ✅ EV 代码签名证书                                        |
| 安装器           | `tauri dev` 或开发签名 | ✅ `.msi` 通过 WiX + `.exe` 单文件                      |
| 单实例锁         | ❌                   | ✅ `tauri-plugin-single-instance`                         |
| 原生菜单 / 快捷键 | 部分                 | ✅ 完整：File / Edit / View / Help 菜单                   |
| WebView2 引导    | 假设已有             | ✅ 安装器内置 bootstrapper                                |
| 系统托盘         | ❌                   | 推迟（v1.1）                                              |

### 6.2 更新通道

- `stable` / `beta` 两个 channel，用户在设置可选。
- 更新清单签名 + 安装包签名双重校验。
- 失败回滚：保留上一版本可执行文件，更新失败自动回退。

---

## 7. RLS 启用（🚀）

按 [§4.5.4 Postgres RLS 预案](0001-design.md#454-postgres-rls-预案v11-启用)。MVP-1 已通过 Repository 模式 + 单元 / 集成测试保障数据隔离，MVP-2 在此基础上加最后一道 DB 兜底。

### 7.1 DDL

为所有业务表启用 RLS 并加 `_owner` policy：

```sql
ALTER TABLE characters ENABLE ROW LEVEL SECURITY;
CREATE POLICY characters_owner ON characters
  USING (user_id = current_setting('app.user_id')::uuid)
  WITH CHECK (user_id = current_setting('app.user_id')::uuid);
```

子资源（chapter / volume / vector_document）按 `novel_id → user_id` 关联，可写更复杂的 policy 或在 Repository 层继续兜底。

### 7.2 连接池适配

按 [§4.5.4 连接池适配](0001-design.md#454-postgres-rls-预案v11-启用)：

- 必须事务级 `SET LOCAL app.user_id`，而非会话级 `SET`。
- pgbouncer 模式：`transaction` 或 `session`。
- 请求开始时 `BEGIN` + 设置变量，结束 `COMMIT`。
- BullMQ worker / 后台清理任务用单独的"超级用户"角色绕过 RLS。

### 7.3 灰度策略

- 先在 staging 环境启用一周，对照 MVP-1 单元 / 集成测试套件。
- 生产逐表启用：先 `vector_documents` / `generation_tasks` 等高风险表，再向上铺。
- 每个表启用前后跑性能基准（查询计划对比）。

---

## 8. 性能（🔧）

完整指标表见 [§10.1 性能：分阶段指标](0001-design.md#101-性能分阶段指标)。MVP-1 关注主流程能跑通，MVP-2 必须**全部达到 P95 指标**：

| 类别                 | MVP-2 关键指标                                                       |
| -------------------- | -------------------------------------------------------------------- |
| 导入流水线（10 万字） | P95 ≤ 5 分钟（[§10.1.1](0001-design.md#1011-导入流水线10-万字-txt-为基准)） |
| 章节生成              | P95 TTFB ≤ 6 s；3000 字完整 ≤ 120 s（[§10.1.2](0001-design.md#1012-章节生成)） |
| RAG 检索（4 路并发）  | P95 ≤ 500 ms（[§10.1.2](0001-design.md#1012-章节生成)）              |
| 向量检索（单路）      | P95 < 300 ms                                                         |
| 前端 TTI              | Web < 2 s（gzip 主 JS < 400 KB）；桌面 < 3 s                          |
| 编辑器输入延迟        | < 50 ms                                                              |
| 负载测试              | ≥ 50 RPS 综合负载稳定运行                                            |

### 8.1 优化重点

按 [§10.1.1 不达标的优化方向](0001-design.md#1011-导入流水线10-万字-txt-为基准) 落地：

- 摘要 / 抽取并发上限默认 5，按 Provider TPS 上调。
- 长章节按 [§6.9](0001-design.md#69-长章节摘要分块策略) map 阶段全并行。
- Embedding 合并 batch（≤ 32 条 / ≤ 8000 token）。
- 向量索引：超过 100 万条切 HNSW（pgvector ≥ 0.5）。
- 导入完成后对涉及的 fandom 做一次 `ANALYZE vector_documents`。
- 每日低峰跑全表 `REINDEX`。

### 8.2 负载测试

- 工具：k6 / Locust。
- 场景：50 并发模拟用户，按"50% 浏览 / 30% 编辑 / 15% 生成 / 5% 导入"分布跑 30 分钟。
- 通过条件：P95 达成 §8 表格 + 错误率 < 0.5%。

---

## 9. 国际化与合规（🆕）

### 9.1 i18n 基础设施

按 [§10.5 国际化](0001-design.md#105-国际化)：

- 所有 UI 文本提取到 `i18n/{locale}.json`，默认 `zh-CN`。
- 日期 / 数字格式化用 `Intl` API。
- 后端错误消息也走 i18n（按 `Accept-Language` 选）。
- MVP-2 仍只发简体中文，但代码结构必须落地。

### 9.2 合规文案

- 隐私政策 / 用户协议：法务过审版本。注册流程强制勾选。
- Cookie 提示（Web 端）。
- 数据导出路径：从 `/settings/account` 一路可达。
- 数据注销路径：同上。
- 联系方式：客服邮箱 / 工单入口。

---

## 10. 后台管理（🆕）

不在 MVP 用户侧，但运营必需。最小化版本：

| 功能           | 说明                                                  |
| -------------- | ----------------------------------------------------- |
| 用户列表       | 分页 / 搜索；查看注册时间、最近活跃、用量            |
| 配额调整       | 单用户级覆盖软 / 硬上限（针对 VIP / 测试账号）        |
| 反馈处理       | 接收前端 "为什么生成结果不对" 反馈（含 RAG 审计 JSON） |
| 账号注销审核   | 缓冲期内的恢复请求处理                                |
| 告警接收       | 配额超限 / 向量不一致 / 备份失败 / LLM 大面积 5xx       |

后台界面**与主应用同源**，但放在子路由 `/admin/*`，独立鉴权 role=`admin`。

---

## 11. 完成定义（DoD）

沿用 [§12.4 MVP-2 完成定义](0001-design.md#124-mvp-2准生产对外week-1218)：

1. **安全审计**：通过基础渗透测试（OWASP Top 10 自检）。具体项目：
   - 注入（SQL / Prompt / 命令）
   - 鉴权 / 会话管理（JWT 失效、refresh rotation、登录锁定）
   - 越权（A 用户访问 B 用户资源 → 100% 拦截）
   - 文件上传（MIME / 扩展名 / 路径穿越 / 大小 / 病毒占位符）
   - 输出 / 日志泄漏（PII 脱敏全路径覆盖）
   - CORS / CSP / HSTS / cookie 安全标志
2. **容灾演练**：从备份恢复整库 ≤ 2 小时。
3. **上线 7 天稳定性**：99.5% 可用。
4. **配额与限流**：满负载（≥ 50 RPS）下无穿透 / 无误杀（误杀率 < 0.1%）。
5. **数据生命周期**：软删过期 → 硬删 → 审计记录全链路通过自动化测试 + 抽样人工检查。

---

## 12. 风险与对策（MVP-2 阶段重点）

| 风险                              | 影响                       | 对策                                                       |
| --------------------------------- | -------------------------- | ---------------------------------------------------------- |
| RLS 启用后查询性能退化            | 主流程响应变慢             | 灰度启用 + 启用前后跑 EXPLAIN 对比 + 性能基准回归测试        |
| 桌面端代码签名证书过期 / 配置错误 | 更新失败 / 安装受阻         | 证书提前 60 天提醒续期；安装器 e2e 测试覆盖 fresh install / 升级 |
| 配额计数器 Redis 故障             | 误杀或穿透                 | Redis 主从 + 故障期间降级为"宽松通过 + 告警 + 离线对账"       |
| 备份未演练 → 真灾难时恢复失败     | 数据丢失                   | 月度演练强制 SOP；演练失败列为 P0 事故                       |
| 内容审核误杀                      | 用户合规体验下降           | 用户可看到具体审核拒绝原因；提供申诉入口                     |
| HardDeleteJob bug 导致误删        | 数据不可恢复               | 幂等 + 二次确认 + `deletion_audit` 留痕 + 灰度（每日删除量 < 阈值时正常执行，超阈值告警人工确认） |
| OWASP 渗透测试发现高危漏洞        | 上线延期                   | 每两周做一次内部安全自检，避免临门一脚                     |

完整风险矩阵见 [§11](0001-design.md#11-风险权衡与缓解)。

---

## 13. MVP 完成后的演进项（v2+）

明确**不在 MVP-2 范围**、纳入产品 Backlog 的高价值项（同 [§12.5](0001-design.md#125-mvp-不包含的演进项v2)）：

- 关系图 / CP / 伏笔 / 时间线
- OOC 检测 / AI 味检测 / 质量评分
- 章节版本对比 / 多版本并存
- 多人协作 / 富文本批注
- epub / pdf / docx 高级解析
- 本地后端模式（SQLite + sqlite-vec）：参见 [§15.2.4](0001-design.md#1524-sqlite--sqlite-vec-离线模式v2-才考虑) 切换权衡
- 移动端
- SSE-KMS 加密 / ClamAV 扫描
- 系统托盘 / PWA 安装
- 多语言（en / ja）正式上线

---

## 14. ADR 与季度回顾

按 [§15.4 切换决策表](0001-design.md#154-切换决策表) 维护 ADR：

- MVP-2 上线时归档当前所有技术选型决策到 `docs/adr/`。
- 每个 ADR 含：决定时间 / 决定人 / 备选方案 / 触发重新评估的条件。
- 每季度回顾一次，根据实际负载情况判断是否切换（典型触发：向量条数 > 1000 万 → 评估 Qdrant；自部署 Sentry 合规要求 → GlitchTip 等）。

---

文档结束。
