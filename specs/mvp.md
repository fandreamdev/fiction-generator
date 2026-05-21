# AI 同人小说创作应用 MVP 设计文档

## 1. MVP 定位

本 MVP 是一个面向同人小说创作的 AI 写作工作台。

核心能力：

- 创建原作知识库
- 导入原文或设定笔记
- 自动拆分章节
- 自动生成章节摘要
- 自动提取人物和世界观候选
- 用户审核候选实体
- 建立基础知识库
- 将知识库向量化
- 创建同人小说项目
- 基于知识库生成同人章节正文
- 保存章节并生成章节摘要
- 将章节摘要继续写入向量库，供后续章节使用

核心闭环：

```txt
导入原作文本/笔记
  ↓
AI 生成章节摘要和候选设定
  ↓
用户审核人物、世界观
  ↓
向量化知识库


新建同人小说
  ↓
填写章节大纲
  ↓
AI 检索相关知识
  ↓
生成章节正文
  ↓
用户保存
  ↓
AI 生成本章摘要
  ↓
本章摘要进入向量库
  ↓
下一章继续使用
```

---

## 2. MVP 核心目标

第一版只解决 4 个问题：

```txt
1. 用户可以创建一个同人小说项目
2. 用户可以导入原作文本/设定笔记，自动生成基础知识库
3. 用户可以管理基础人物、世界观、章节摘要
4. 用户可以基于知识库生成同人章节正文
```

---

## 3. MVP 必做功能

### 3.1 用户与工作台

功能：

```txt
- 用户注册
- 用户登录
- 查看我的小说
- 查看我的原作知识库
- 新建小说
- 新建原作知识库
```

---

### 3.2 原作知识库 Fandom

功能：

```txt
- 新建 Fandom
- 编辑 Fandom
- 查看 Fandom 详情
```

Fandom 信息：

```txt
- 原作名称
- 原作类型
- 简介
- 备注
```

---

### 3.3 导入原文或设定笔记

MVP 支持：

```txt
- txt 文件上传
- markdown 文件上传
- 手动粘贴文本
```

导入后系统自动执行：

```txt
1. 文本清洗
2. 章节切分
3. 保存导入章节
4. 每章生成摘要
5. 每章提取候选人物
6. 每章提取候选世界观
7. 每章提取候选事件
8. 生成向量文档
9. 导入任务进入审核状态
```

---

### 3.4 候选实体审核

导入解析后，用户可以审核：

```txt
- 候选人物
- 候选世界观
- 候选事件
- 章节摘要
```

用户操作：

```txt
- 接受
- 拒绝
- 编辑后接受
```

审核通过后写入正式实体：

```txt
- Character
- WorldSetting
```

---

### 3.5 人物卡管理

功能：

```txt
- 新建人物卡
- 编辑人物卡
- 删除人物卡
- 从候选人物创建人物卡
```

人物卡字段：

```txt
- 名字
- 别名
- 角色定位
- 身份
- 外貌
- 性格
- 能力
- 背景
- 说话风格
- 备注
```

---

### 3.6 世界观管理

功能：

```txt
- 新建世界观条目
- 编辑世界观条目
- 删除世界观条目
- 从候选世界观创建条目
```

世界观类型：

```txt
- 地点
- 组织
- 能力体系
- 物品
- 规则
- 历史
- 其他
```

---

### 3.7 同人小说项目管理

功能：

```txt
- 新建同人小说
- 编辑小说信息
- 查看小说空间
```

创建同人小说时填写：

```txt
- 小说标题
- 关联 Fandom
- 同人类型
- 简介
- 分歧点
- 写作基调
```

同人类型：

```txt
- 原著向
- if线
- 重生
- 穿越
- 现代AU
- 架空AU
- 原作续写
```

---

### 3.8 分卷和章节管理

功能：

```txt
- 默认创建一个分卷
- 新建章节
- 编辑章节标题
- 编辑章节大纲
- 编辑章节正文
- 保存章节
- 完成章节
```

章节核心字段：

```txt
- 章节标题
- 章节序号
- 章节大纲
- 章节正文
- 章节摘要
- 字数
- 状态
```

---

### 3.9 AI 生成章节正文

用户输入：

```txt
- 本章标题
- 本章大纲
- 出场人物
- 本章目标
- 额外要求
```

系统自动读取：

```txt
- 当前 Novel 信息
- 写作风格
- 分歧点
- 本章大纲
- 相关人物卡
- 相关世界观
- 原作章节摘要
- 前文章节摘要
- 向量检索结果
```

然后调用大模型生成正文。

Prompt 内容结构：

```txt
【小说信息】
【同人类型】
【分歧点】
【写作风格】
【本章大纲】
【相关人物】
【相关世界观】
【相关原作摘要】
【前文摘要】
【生成要求】
```

---

### 3.10 章节完成与摘要更新

用户点击：

```txt
完成本章
```

系统执行：

```txt
1. 根据章节正文生成 Chapter.summary
2. 保存 summary
3. 统计章节字数
4. 把章节摘要写入 VectorDocument
5. 后续章节生成时可以检索到该章节摘要
```

---

### 3.11 向量检索

MVP 需要支持基础 RAG。

需要向量化的内容：

```txt
- 导入章节摘要
- 人物卡
- 世界观条目
- 同人章节摘要
- 写作风格
```

生成章节时检索：

```txt
- 相关人物
- 相关世界观
- 相关原作摘要
- 相关前文摘要
```

---

### 3.12 生成任务记录

每次 AI 调用都记录：

```txt
- 任务类型
- 输入 Prompt
- 输出内容
- 状态
- 错误信息
- 使用模型
- 创建时间
```

用于：

```txt
- 调试
- 查看历史生成结果
- 失败重试
```

---

## 4. MVP 暂不做功能

第一版不做：

```txt
1. 自动 CP 识别
2. 自动伏笔识别
3. 复杂人物关系图谱
4. OOC 高级检测
5. AI 味评分
6. 多版本章节对比
7. epub/pdf/docx 高级解析
8. 全文相似度检测
9. 自动发布到平台
10. 多人协作
11. 时间线可视化
12. 地图/地点系统
13. 道具系统
14. 富文本批注
15. 高级权限系统
```

---

## 5. MVP 实体类清单

MVP 最小数据表：

```txt
users
fandoms
novels
import_tasks
imported_chapters
extraction_candidates
characters
world_settings
volumes
chapters
writing_styles
vector_documents
generation_tasks
```

共 13 张表。

---

## 6. 实体类设计

### 6.1 User 用户

```txt
User
```

字段：

```txt
id
email
passwordHash
nickname
createdAt
updatedAt
```

---

### 6.2 Fandom 原作知识库

```txt
Fandom
```

字段：

```txt
id
userId
name
type
description
notes
createdAt
updatedAt
```

说明：

```txt
type 可选值：小说/动漫/游戏/影视/其他
```

---

### 6.3 Novel 同人小说项目

```txt
Novel
```

字段：

```txt
id
userId
fandomId
title
type
fanficType
description
divergencePoint
tone
status
createdAt
updatedAt
```

说明：

```txt
type 可选值：fanfic/original
fanficType 可选值：原著向/if线/重生/穿越/AU/续写
status 可选值：draft/writing/finished
```

---

### 6.4 ImportTask 导入任务

```txt
ImportTask
```

字段：

```txt
id
userId
fandomId
fileName
sourceType
status
progress
errorMessage
createdAt
updatedAt
```

说明：

```txt
sourceType 可选值：txt/markdown/paste
status 可选值：pending/processing/reviewing/completed/failed
```

---

### 6.5 ImportedChapter 导入章节

```txt
ImportedChapter
```

字段：

```txt
id
importTaskId
fandomId
chapterNo
title
content
summary
wordCount
status
createdAt
updatedAt
```

说明：

```txt
content 可选，后期可改为不长期保存原文
status 可选值：pending/summarized/failed
```

---

### 6.6 ExtractionCandidate 抽取候选实体

```txt
ExtractionCandidate
```

字段：

```txt
id
userId
fandomId
importTaskId
sourceChapterId
entityType
name
contentJson
confidence
status
targetEntityId
createdAt
updatedAt
```

说明：

```txt
entityType 可选值：CHARACTER/WORLD_SETTING/EVENT
status 可选值：pending/approved/rejected
```

contentJson 示例：

```json
{
  "name": "林渊",
  "identity": "青云宗弟子",
  "personality": "谨慎、隐忍",
  "appearance": "黑衣少年",
  "evidence": "第3章、第5章多次出现"
}
```

---

### 6.7 Character 人物卡

```txt
Character
```

字段：

```txt
id
userId
fandomId
novelId
name
aliases
role
identity
appearance
personality
abilities
background
speakingStyle
notes
sourceType
createdAt
updatedAt
```

说明：

```txt
novelId 可为空
- novelId 为空：表示 Fandom 级别的原作人物
- novelId 不为空：表示某个同人项目里的角色版本

sourceType 可选值：manual/imported/ai
```

---

### 6.8 WorldSetting 世界观条目

```txt
WorldSetting
```

字段：

```txt
id
userId
fandomId
novelId
category
name
description
rules
notes
sourceType
createdAt
updatedAt
```

说明：

```txt
novelId 可为空

category 可选值：
- 地点
- 组织
- 能力体系
- 物品
- 规则
- 历史
- 其他

sourceType 可选值：manual/imported/ai
```

---

### 6.9 Volume 分卷

```txt
Volume
```

字段：

```txt
id
novelId
title
orderIndex
summary
createdAt
updatedAt
```

说明：

```txt
MVP 可默认创建一个“正文卷”
```

---

### 6.10 Chapter 章节

```txt
Chapter
```

字段：

```txt
id
novelId
volumeId
chapterNo
title
outline
content
summary
wordCount
status
createdAt
updatedAt
```

说明：

```txt
status 可选值：draft/generated/final
summary 是长篇连续生成的核心字段
```

---

### 6.11 WritingStyle 写作风格

```txt
WritingStyle
```

字段：

```txt
id
userId
novelId
name
description
tone
pacing
dialogueStyle
descriptionStyle
avoidRules
createdAt
updatedAt
```

---

### 6.12 VectorDocument 向量文档

```txt
VectorDocument
```

字段：

```txt
id
userId
fandomId
novelId
sourceType
sourceId
chunkText
embedding
metadata
createdAt
updatedAt
```

说明：

```txt
sourceType 可选值：
- IMPORTED_CHAPTER_SUMMARY
- CHARACTER
- WORLD_SETTING
- CHAPTER_SUMMARY
- WRITING_STYLE
```

metadata 示例：

```json
{
  "fandomId": "fandom_001",
  "novelId": "novel_001",
  "sourceType": "CHARACTER",
  "characterName": "林渊",
  "importance": 8
}
```

---

### 6.13 GenerationTask 生成任务

```txt
GenerationTask
```

字段：

```txt
id
userId
novelId
chapterId
taskType
status
modelName
promptText
resultText
errorMessage
createdAt
updatedAt
```

说明：

```txt
taskType 可选值：
- IMPORT
- SUMMARY
- EXTRACT
- GENERATE_CHAPTER
- GENERATE_CHAPTER_SUMMARY
- EMBEDDING

status 可选值：
- pending
- running
- success
- failed
```

---

## 7. 实体关系图

```txt
User
 ├── Fandom 原作知识库
 │    ├── ImportTask 导入任务
 │    │    ├── ImportedChapter 导入章节
 │    │    └── ExtractionCandidate 抽取候选
 │    ├── Character 原作人物卡
 │    ├── WorldSetting 原作世界观
 │    └── VectorDocument 原作向量文档
 │
 └── Novel 同人小说项目
      ├── WritingStyle 写作风格
      ├── Volume 分卷
      │    └── Chapter 章节
      ├── Character 同人角色版本，可选
      ├── WorldSetting 同人私设，可选
      ├── VectorDocument 小说向量文档
      └── GenerationTask 生成任务
```

---

## 8. 应用使用流程

### 8.1 流程一：创建原作知识库

```txt
1. 用户登录
2. 点击「新建原作知识库」
3. 输入：
   - 原作名称
   - 原作类型
   - 简介
   - 备注
4. 系统创建 Fandom
5. 用户进入 Fandom 详情页
```

---

### 8.2 流程二：导入原文或设定笔记

```txt
1. 用户进入 Fandom 页面
2. 点击「导入文本」
3. 上传 txt/markdown 或粘贴文本
4. 系统创建 ImportTask
5. 后台开始解析
```

后台处理：

```txt
1. 文本清洗
2. 章节切分
3. 保存 ImportedChapter
4. 每章生成 summary
5. 每章提取候选人物
6. 每章提取候选世界观
7. 每章提取候选事件
8. 生成 VectorDocument
9. ImportTask 状态变为 reviewing
```

---

### 8.3 流程三：审核 AI 抽取结果

```txt
1. 用户进入「解析结果审核」
2. 查看候选人物
3. 对候选人物执行：
   - 接受
   - 拒绝
   - 编辑后接受
4. 查看候选世界观
5. 对候选世界观执行：
   - 接受
   - 拒绝
   - 编辑后接受
6. 系统把审核通过的内容写入 Character 和 WorldSetting
7. 系统为通过的内容生成向量
8. 原作知识库建立完成
```

---

### 8.4 流程四：新建同人小说项目

```txt
1. 用户点击「新建小说」
2. 选择「同人小说」
3. 选择关联的 Fandom
4. 填写：
   - 小说标题
   - 同人类型
   - 简介
   - 分歧点
   - 写作基调
5. 系统创建 Novel
6. 系统默认创建一个 Volume
7. 系统默认创建一个 WritingStyle
8. 用户进入小说空间
```

示例：

```txt
小说标题：《如果他提前知道真相》
同人类型：if线
分歧点：主角在原作第十二章之前得知关键真相，因此提前改变行动。
写作基调：慢热、克制、偏剧情。
```

---

### 8.5 流程五：创建章节

```txt
1. 用户进入小说空间
2. 点击「新建章节」
3. 输入：
   - 章节标题
   - 章节大纲
   - 出场人物
   - 本章目标
   - 额外要求
4. 系统保存为 Chapter
```

示例：

```txt
章节标题：雨夜来客

章节大纲：
A 在雨夜发现 B 受伤来到门外。
A 明知道 B 隐瞒了某个秘密，但仍然放他进屋。
两人试探交谈。
结尾 A 发现 B 身上带着原作中本不该出现的信物。
```

---

### 8.6 流程六：AI 生成章节正文

用户点击：

```txt
生成正文
```

系统执行：

```txt
1. 读取当前 Novel 信息
2. 读取 WritingStyle
3. 读取 Chapter.outline
4. 根据章节大纲构造检索 query
5. 从 VectorDocument 中检索相关内容
6. 获取相关人物卡
7. 获取相关世界观
8. 获取前几章 Chapter.summary
9. 拼接 Prompt
10. 调用大模型
11. 保存 GenerationTask
12. 返回生成结果
```

Prompt 结构：

```txt
【小说信息】
标题：
同人类型：
分歧点：
写作基调：

【写作风格】
语气：
节奏：
对话风格：
描写风格：
避免事项：

【本章大纲】
...

【相关人物】
...

【相关世界观】
...

【相关原作摘要】
...

【前文摘要】
...

【生成要求】
请根据以上信息生成本章正文。
```

---

### 8.7 流程七：用户编辑并保存章节

```txt
1. AI 返回正文
2. 用户手动修改正文
3. 用户点击「保存章节」
4. 系统更新 Chapter.content
5. 系统统计 wordCount
6. Chapter.status 更新为 generated 或 draft
```

---

### 8.8 流程八：完成章节并生成摘要

用户点击：

```txt
完成本章
```

系统执行：

```txt
1. 根据 Chapter.content 生成 Chapter.summary
2. 保存 summary
3. 统计章节字数
4. Chapter.status 更新为 final
5. 把 summary 写入 VectorDocument
6. 后续章节可以检索到这一章
```

---

## 9. 推荐页面结构

### 9.1 登录页

```txt
- 邮箱
- 密码
- 登录
- 注册
```

---

### 9.2 首页 / 工作台

```txt
- 我的小说
- 我的原作知识库
- 新建小说
- 新建知识库
```

---

### 9.3 Fandom 详情页

```txt
- 原作名称
- 简介
- 导入文本按钮
- 章节摘要列表
- 人物卡列表
- 世界观列表
```

---

### 9.4 导入审核页

```txt
- 导入任务进度
- 候选人物
- 候选世界观
- 候选事件
- 接受
- 拒绝
- 编辑后接受
```

---

### 9.5 小说空间页

```txt
- 小说信息
- 分卷列表
- 章节列表
- 人物
- 世界观
- 写作风格
```

---

### 9.6 章节编辑页

核心页面。

```txt
左侧：
- 章节列表

中间：
- 章节标题
- 章节大纲
- 正文编辑器

右侧：
- AI 助手
```

AI 助手按钮：

```txt
- 生成正文
- 重新生成
- 生成摘要
- 保存并完成本章
```

---

## 10. 推荐技术选型

### 10.1 主数据库

推荐：

```txt
PostgreSQL
```

原因：

```txt
- 关系型数据好管理
- 支持 JSONB
- 可以接 pgvector
- MVP 架构简单
```

---

### 10.2 向量数据库

MVP 推荐：

```txt
PostgreSQL + pgvector
```

---

### 10.3 Embedding 模型

推荐二选一：

```txt
text-embedding-3-small
或
bge-m3
```

选择建议：

```txt
- 想省事：text-embedding-3-small
- 想中文效果更好并可自部署：bge-m3
```

---

### 10.4 大模型

用于：

```txt
- 章节摘要
- 实体抽取
- 章节生成
```

可接：

```txt
- OpenAI
- Claude
- Qwen
- DeepSeek
- Gemini
```

---

### 10.5 后台任务队列

导入和生成都建议异步。

推荐：

```txt
Node.js：BullMQ + Redis
Python：Celery + Redis
```

---

## 11. MVP 后端接口建议

### 11.1 Fandom 接口

```txt
POST /fandoms
GET /fandoms
GET /fandoms/:id
PUT /fandoms/:id
```

---

### 11.2 Import 接口

```txt
POST /fandoms/:id/imports
GET /imports/:id
GET /imports/:id/chapters
GET /imports/:id/candidates
POST /candidates/:id/approve
POST /candidates/:id/reject
```

---

### 11.3 Character 接口

```txt
GET /fandoms/:id/characters
POST /fandoms/:id/characters
PUT /characters/:id
DELETE /characters/:id
```

---

### 11.4 WorldSetting 接口

```txt
GET /fandoms/:id/world-settings
POST /fandoms/:id/world-settings
PUT /world-settings/:id
DELETE /world-settings/:id
```

---

### 11.5 Novel 接口

```txt
POST /novels
GET /novels
GET /novels/:id
PUT /novels/:id
```

---

### 11.6 Chapter 接口

```txt
POST /novels/:id/chapters
GET /novels/:id/chapters
GET /chapters/:id
PUT /chapters/:id
POST /chapters/:id/generate
POST /chapters/:id/summarize
POST /chapters/:id/complete
```

---

## 12. 第一版开发优先级

### P0：必须完成

```txt
1. 用户注册/登录
2. 新建 Fandom
3. 导入 txt/粘贴文本
4. 章节切分
5. 章节摘要生成
6. 候选人物提取
7. 候选世界观提取
8. 审核候选实体
9. 新建 Novel
10. 新建 Chapter
11. AI 生成章节正文
12. 保存章节
13. 生成章节摘要
14. 向量化和基础检索
```

---

### P1：完成后增强

```txt
1. 写作风格编辑
2. 生成任务历史
3. 重新生成正文
4. 导入 markdown 文件
5. 世界观分类筛选
6. 人物卡搜索
```

---

### P2：后续版本

```txt
1. CP/Ship
2. 人物关系图
3. 伏笔系统
4. 时间线系统
5. OOC 检查
6. 角色声音卡
7. 章节版本管理
8. AI 质量检测
```

---

## 13. 第二阶段可新增实体

MVP 跑通后，可以增加：

```txt
Relationship 人物关系
Ship CP/配对
Foreshadowing 伏笔
StoryEvent 时间线事件
CharacterState 人物动态状态
OOCCheckRule OOC规则
VoiceProfile 角色声音卡
ChapterVersion 章节版本
AIQualityRule AI质量规则
CanonComplianceReport 原作一致性报告
```

---

## 14. 最小 MVP 总结

一句话描述：

```txt
用户创建原作知识库，导入文本，AI 自动拆章摘要并提取人物/世界观候选；用户审核后形成可向量检索的知识库；然后用户新建同人小说，填写章节大纲，AI 自动检索相关知识并生成章节正文，保存后生成章节摘要供下一章继续使用。
```

最终 MVP 闭环：

```txt
Fandom 创建
  ↓
文本导入
  ↓
章节切分
  ↓
摘要与候选实体抽取
  ↓
用户审核
  ↓
知识库向量化
  ↓
Novel 创建
  ↓
Chapter 创建
  ↓
RAG 检索
  ↓
AI 生成正文
  ↓
用户保存
  ↓
章节摘要生成
  ↓
进入下一章
```

```

```
