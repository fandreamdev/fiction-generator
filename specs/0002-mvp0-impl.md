# 同人小说创作应用 — MVP-0 实现文档

- 文档编号：0002-mvp0-impl
- 配套设计：[0002-mvp0-design.md](0002-mvp0-design.md)
- 配套计划：[0002-mvp0-plan.md](0002-mvp0-plan.md)
- 上游全景：[0001-design.md](0001-design.md)
- 编写日期：2026-05-21

---

## 0. 文档目标

本文是 MVP-0 的从 0 到 1 实现手册。目标是让 1 个开发者按本文执行后，可以在本机跑通：

```
创建 Fandom
  -> 上传 txt
  -> 清洗 + 切章 + 摘要 + 实体抽取 + 向量化
  -> 审核候选实体
  -> 创建 Novel
  -> 创建章节
  -> RAG 检索 + AI 生成首章
  -> 完成本章 + 摘要回灌 + 向量化
  -> 生成第二章时引用第一章事件
```

本文默认仓库从空工程开始实现。若仓库中已经存在部分目录或文件，按本文检查并补齐即可。

> 注释：本文刻意写成“操作手册”而不是“架构说明”。设计文档负责说明要做什么，计划文档负责拆任务，本文负责让开发者在没有上下文时也能照着创建文件、执行命令、补齐类和方法。这样可以减少实现阶段反复回查多个文档的成本。

> 零基础阅读提示：如果你不知道某个命令、文件或模块为什么存在，先按本文主流程执行，再对照最后的“15. 零基础逐步解释”阅读。该章节按实现顺序解释每一步在系统里承担的作用、为什么不能省、做完后应该得到什么结果。

> 指令阅读提示：本文会把命令解释直接放在命令出现的位置附近。读到一条命令时，先看紧跟其后的“命令解释 / 成功标志 / 常见问题”，再执行。

---

## 1. 技术栈与全局约定

### 1.1 技术栈

| 层        | 选择                                     |
| --------- | ---------------------------------------- |
| 包管理    | pnpm workspace                           |
| 后端      | NestJS + TypeScript + Node.js 20+        |
| ORM       | Prisma                                   |
| 数据库    | PostgreSQL 16 + pgvector                 |
| 队列      | BullMQ + Redis 7                         |
| 对象存储  | MinIO                                    |
| LLM       | OpenAI 兼容接口，MVP-0 写死一个 Provider |
| Embedding | `text-embedding-3-small`，1536 维        |
| 前端      | React + TypeScript + Vite                |
| UI        | Tailwind CSS + shadcn/ui                 |
| 请求状态  | TanStack Query                           |

> 注释：MVP-0 的技术栈优先选择“主流、资料多、能快速闭环”的组合，而不是最完美的长期架构。NestJS + Prisma + PostgreSQL 可以快速建立类型化后端；BullMQ + Redis 适合处理 LLM 调用这种耗时任务；MinIO 用来提前验证对象存储路径，避免 MVP-1 接入真实 S3 时重做上传模型。

### 1.2 固定 demo user

MVP-0 不做登录。所有请求自动注入：

```ts
export const DEMO_USER_ID = "00000000-0000-0000-0000-000000000001";
```

所有业务表仍然保留 `user_id` 字段。Service 查询必须带 `userId` 过滤，为 MVP-1 多用户做准备。

> 注释：MVP-0 不做登录是为了缩短技术闭环，但保留 `user_id` 是为了避免后续多用户改造时迁移所有表。middleware 写死 demo user 的方式可以让业务代码提前养成“所有数据访问都带 userId”的约束，MVP-1 替换为真实 AuthGuard 时影响面最小。

### 1.3 目录最终形态

实现完成后，仓库目录应至少包含：

```text
fiction/
├── .env.example
├── docker-compose.yml
├── package.json
├── pnpm-workspace.yaml
├── apps/
│   ├── api/
│   │   ├── prisma/
│   │   │   ├── schema.prisma
│   │   │   ├── seed.ts
│   │   │   └── migrations/
│   │   ├── src/
│   │   │   ├── main.ts
│   │   │   ├── app.module.ts
│   │   │   ├── common/
│   │   │   ├── modules/
│   │   │   │   ├── fandom/
│   │   │   │   ├── import/
│   │   │   │   ├── extraction/
│   │   │   │   ├── novel/
│   │   │   │   ├── chapter/
│   │   │   │   ├── rag/
│   │   │   │   ├── llm/
│   │   │   │   ├── storage/
│   │   │   │   └── task/
│   │   │   ├── prompts/
│   │   │   └── workers/
│   │   └── test/
│   └── web/
│       ├── src/
│       │   ├── api/
│       │   ├── components/
│       │   ├── hooks/
│       │   ├── pages/
│       │   ├── routes.tsx
│       │   └── main.tsx
│       └── index.html
├── packages/
│   └── shared/
│       ├── src/
│       └── package.json
├── scripts/
│   ├── smoke-import.ps1
│   └── smoke-generation.ps1
└── specs/
```

> 注释：目录按“应用 / 共享包 / 脚本 / 文档”分层。`apps/api` 和 `apps/web` 分离，便于后续桌面端复用 Web；`packages/shared` 放前后端共享类型，避免接口字段在两边手写漂移；`scripts` 放 smoke 测试，保证关键链路可以用命令行复现。

---

## 2. S0：基础设施与项目骨架

### 2.1 创建 workspace

在仓库根目录执行：

```bash
corepack enable pnpm
pnpm init
```

命令解释：

- `corepack enable pnpm`：启用 Node.js 自带的 Corepack，并让 Corepack 帮你调用 pnpm。pnpm 是本项目的包管理器，负责安装依赖、执行脚本、管理 monorepo。执行后可用 `pnpm --version` 检查是否成功。
- `pnpm init`：在当前目录创建 `package.json`。`package.json` 是 Node.js 项目的说明文件，后续脚本和依赖都写在这里。
- 这两条命令必须在仓库根目录 `D:\fiction` 执行。目录错了会把 `package.json` 建到错误位置。

创建 `pnpm-workspace.yaml`：

```yaml
packages:
  - "apps/*"
  - "packages/*"
```

修改根 `package.json`：

```json
{
  "name": "fiction",
  "private": true,
  "scripts": {
    "dev": "pnpm -r --parallel dev",
    "build": "pnpm -r build",
    "lint": "pnpm -r lint",
    "test": "pnpm -r test",
    "format": "prettier --write ."
  },
  "devDependencies": {
    "prettier": "^3.3.3",
    "typescript": "^5.6.3"
  }
}
```

创建 `.gitignore`：

```gitignore
node_modules
dist
.env
.env.local
.DS_Store
coverage
apps/api/prisma/migrations/*/migration_lock.toml
```

创建 `.env.example`：

```bash
NODE_ENV=development

DATABASE_URL=postgresql://fiction:fiction@localhost:5432/fiction?schema=public
REDIS_HOST=localhost
REDIS_PORT=6379

MINIO_ENDPOINT=localhost
MINIO_PORT=9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_BUCKET=fiction
MINIO_USE_SSL=false

LLM_API_KEY=
LLM_BASE_URL=https://api.openai.com/v1
LLM_MODEL=gpt-4o-mini
LLM_EMBEDDING_MODEL=text-embedding-3-small

WEB_ORIGIN=http://localhost:5173
API_PORT=3000
```

复制环境文件：

```bash
cp .env.example .env
```

命令解释：

- `cp .env.example .env`：把配置模板复制成真实本地配置文件。
- `.env.example` 可以提交到 Git，`.env` 不能提交，因为里面会填真实数据库连接和 LLM API key。
- 这条命令适合 macOS / Linux / Git Bash。PowerShell 推荐使用下面的 `Copy-Item`。

Windows PowerShell 可执行：

```powershell
Copy-Item .env.example .env
```

命令解释：

- `Copy-Item .env.example .env`：PowerShell 的复制文件命令，作用和 `cp .env.example .env` 相同。
- 成功标志：根目录出现 `.env` 文件。
- 常见问题：如果提示文件已存在，说明你之前已经复制过；通常不需要覆盖，除非 `.env.example` 新增了配置项。

> 注释：`.env.example` 必须提交，`.env` 必须忽略。这样既能让新开发者知道需要哪些配置，又不会把 LLM API key、数据库密码等本地密钥提交到仓库。MVP-0 虽然不面向生产，但这个习惯会直接影响后续安全边界。

### 2.2 创建 docker-compose

创建 `docker-compose.yml`：

```yaml
services:
  postgres:
    image: pgvector/pgvector:pg16
    container_name: fiction-postgres
    environment:
      POSTGRES_USER: fiction
      POSTGRES_PASSWORD: fiction
      POSTGRES_DB: fiction
    ports:
      - "5432:5432"
    volumes:
      - fiction-postgres:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    container_name: fiction-redis
    ports:
      - "6379:6379"

  minio:
    image: minio/minio:latest
    container_name: fiction-minio
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - fiction-minio:/data

volumes:
  fiction-postgres:
  fiction-minio:
```

启动依赖：

```bash
docker compose up -d
docker compose ps
```

命令解释：

- `docker compose up -d`：根据 `docker-compose.yml` 创建并启动 PostgreSQL、Redis、MinIO。`-d` 表示后台运行，不占用当前终端。
- `docker compose ps`：查看这些容器是否已经启动。
- 成功标志：`postgres`、`redis`、`minio` 三个服务都显示 running / Up。
- 常见问题：如果端口被占用，检查本机是否已有 PostgreSQL、Redis 或 MinIO 正在使用 `5432`、`6379`、`9000`、`9001`。

验收：

- PostgreSQL 监听 `localhost:5432`
- Redis 监听 `localhost:6379`
- MinIO 控制台 `http://localhost:9001` 可打开

> 注释：MVP-0 要求“一套 docker-compose 能跑通”，所以数据库、队列、对象存储都放在本地容器里。PostgreSQL 镜像选择 `pgvector/pgvector:pg16`，是为了避免手动编译 pgvector 扩展；MinIO 即使当前只存 txt 原文，也能提前验证“文件不直接塞数据库”的架构路径。

### 2.3 创建 NestJS API

执行：

```bash
pnpm dlx @nestjs/cli new apps/api --package-manager pnpm --skip-git
```

命令解释：

- `pnpm dlx`：临时下载并执行一个命令行工具，不把它永久安装到项目依赖里。
- `@nestjs/cli`：NestJS 官方脚手架工具。
- `new apps/api`：创建一个新的 NestJS 项目，目录是 `apps/api`。
- `--package-manager pnpm`：让脚手架使用 pnpm。
- `--skip-git`：不要在 `apps/api` 里再初始化一个 Git 仓库，因为根目录已经是 Git 仓库。
- 成功标志：出现 `apps/api/package.json`、`apps/api/src/main.ts`、`apps/api/src/app.module.ts`。

进入 API 安装依赖：

```bash
cd apps/api
pnpm add @nestjs/config @nestjs/platform-express @nestjs/swagger
pnpm add @prisma/client
pnpm add prisma -D
pnpm add class-validator class-transformer
pnpm add bullmq @bull-board/api @bull-board/express
pnpm add ioredis
pnpm add multer @types/multer -D
pnpm add minio
pnpm add openai
pnpm add zod
pnpm add uuid
pnpm add tsx -D
cd ../..
```

命令解释：

- `cd apps/api`：进入后端项目目录。后面的 `pnpm add` 会把依赖写入 `apps/api/package.json`。
- `pnpm add ...`：安装运行时依赖，应用启动时会用到。
- `pnpm add ... -D`：安装开发依赖，只在开发、构建或脚本执行时使用。
- `@nestjs/config` 用于读取 `.env`；`@nestjs/swagger` 用于 API 文档；`@prisma/client` 用于运行时访问数据库；`bullmq` / `ioredis` 用于队列；`minio` 用于对象存储；`openai` 用于 LLM；`tsx` 用于直接运行 TypeScript 脚本。
- `cd ../..`：从 `apps/api` 回到仓库根目录。
- 成功标志：`apps/api/package.json` 中出现这些 dependencies / devDependencies。

在 `apps/api/package.json` 中保留或补齐脚本：

```json
{
  "scripts": {
    "dev": "nest start --watch",
    "build": "nest build",
    "start": "node dist/main.js",
    "lint": "eslint \"{src,test}/**/*.ts\"",
    "test": "jest",
    "test:cov": "jest --coverage",
    "prisma": "prisma",
    "prisma:generate": "prisma generate",
    "prisma:migrate": "prisma migrate dev",
    "seed": "tsx prisma/seed.ts",
    "llm:ping": "tsx src/scripts/llm-ping.ts"
  }
}
```

> 注释：NestJS 模块化结构和 MVP-0 的业务边界吻合：Fandom、Import、Extraction、Novel、Chapter、RAG、LLM 都可以各自成为模块。这样后续添加鉴权、Repository、可观测性时可以按模块扩展，而不是在一个大 service 中拆分。

### 2.4 创建 Vite React Web

执行：

```bash
pnpm create vite apps/web --template react-ts
cd apps/web
pnpm add @tanstack/react-query axios zustand react-router-dom
pnpm add clsx tailwind-merge lucide-react
pnpm add tailwindcss @tailwindcss/vite
pnpm dlx tailwindcss init -p
cd ../..
```

命令解释：

- `pnpm create vite apps/web --template react-ts`：用 Vite 创建 React + TypeScript 前端项目，目录是 `apps/web`。
- `cd apps/web`：进入前端项目目录，让依赖安装到 `apps/web/package.json`。
- `pnpm add @tanstack/react-query axios zustand react-router-dom`：安装前端运行时依赖。React Query 管接口数据，axios 发 HTTP 请求，router 管页面路由。
- `pnpm add tailwindcss @tailwindcss/vite`：安装样式构建相关开发依赖。
- `pnpm dlx tailwindcss init -p`：生成 `tailwind.config.js` 和 `postcss.config.js`。
- 成功标志：`apps/web/src/main.tsx` 存在，`apps/web/package.json` 中出现这些依赖。

安装 shadcn/ui：

```bash
cd apps/web
pnpm dlx shadcn@latest init
pnpm dlx shadcn@latest add button input textarea dialog card tabs table select badge progress toast
cd ../..
```

命令解释：

- `pnpm dlx shadcn@latest init`：初始化 shadcn/ui 配置，通常会生成 `components.json` 和工具函数。
- `pnpm dlx shadcn@latest add ...`：把按钮、输入框、弹窗、表格、进度条等组件源码添加到项目。
- shadcn/ui 不是黑盒组件库，它会把组件代码放进你的仓库，后续可以直接修改。
- 成功标志：`apps/web/src/components/ui/` 下出现 button、input、dialog 等组件文件。

`apps/web/package.json` 脚本：

```json
{
  "scripts": {
    "dev": "vite --host 0.0.0.0 --port 5173",
    "build": "tsc -b && vite build",
    "lint": "eslint .",
    "preview": "vite preview"
  }
}
```

> 注释：前端不使用 Next.js，是因为 MVP-0 不需要 SSR、SEO 或服务端路由。Vite 更轻，能快速启动；React SPA 足够承载本地 dogfood 场景。shadcn/ui 只作为组件源码工具，不引入复杂设计系统。

### 2.5 创建 shared 包

创建 `packages/shared/package.json`：

```json
{
  "name": "@fiction/shared",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": {
    "build": "tsc -p tsconfig.json",
    "dev": "tsc -p tsconfig.json --watch",
    "lint": "tsc -p tsconfig.json --noEmit",
    "test": "echo \"no tests\""
  },
  "devDependencies": {
    "typescript": "^5.6.3"
  }
}
```

创建 `packages/shared/tsconfig.json`：

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "declaration": true,
    "outDir": "dist",
    "strict": true,
    "skipLibCheck": true
  },
  "include": ["src"]
}
```

创建 `packages/shared/src/index.ts`，先放 API DTO 类型和枚举字符串类型：

```ts
export type ImportStatus =
  | "pending"
  | "processing"
  | "reviewing"
  | "completed"
  | "failed";
export type ImportStage =
  | "cleaning"
  | "splitting"
  | "summarizing"
  | "extracting"
  | "embedding";
export type CandidateType = "CHARACTER" | "WORLD_SETTING" | "EVENT";
export type CandidateStatus = "pending" | "approved" | "rejected";
export type ChapterStatus = "draft" | "generated" | "final";
export type GenerationTaskStatus = "pending" | "running" | "success" | "failed";
```

根目录安装依赖：

```bash
pnpm install
```

命令解释：

- `pnpm install`：读取根目录和 workspace 子项目的 `package.json`，下载所有依赖，并生成 `pnpm-lock.yaml`。
- `pnpm-lock.yaml` 记录依赖的精确版本，应该提交到 Git，保证不同机器安装到同一批依赖。
- 成功标志：命令结束无 error，根目录出现 `node_modules` 和 `pnpm-lock.yaml`。

> 注释：共享包先只放类型和枚举，不放业务逻辑。这样可以解决前后端接口字段一致性问题，同时避免 shared 包过早变成“公共杂物箱”。真正稳定后再考虑把 DTO schema 或 zod 校验也迁入共享包。

---

## 3. S1：数据库与后端基础能力

### 3.1 Prisma 初始化

执行：

```bash
cd apps/api
pnpm prisma init
cd ../..
```

命令解释：

- `cd apps/api`：进入后端项目目录，因为 Prisma 配置属于后端。
- `pnpm prisma init`：创建 Prisma 初始化文件，最重要的是 `apps/api/prisma/schema.prisma`。
- `cd ../..`：回到仓库根目录。
- 成功标志：出现 `apps/api/prisma/schema.prisma`。

将 `apps/api/prisma/schema.prisma` 改为 PostgreSQL。MVP-0 可先使用 Prisma enum 管理普通枚举，`vector` 列通过手写 SQL migration 添加。

必须实现的 model：

- `User`
- `Fandom`
- `Novel`
- `ImportTask`
- `ImportedChapter`
- `ExtractionCandidate`
- `Character`
- `WorldSetting`
- `Volume`
- `Chapter`
- `WritingStyle`
- `VectorDocument`
- `GenerationTask`

字段要求以 [0001-design.md §4.2](0001-design.md#42-核心表) 为准，且每张业务表都增加：

```prisma
deletedAt DateTime? @map("deleted_at") @db.Timestamptz
createdAt DateTime  @default(now()) @map("created_at") @db.Timestamptz
updatedAt DateTime  @updatedAt @map("updated_at") @db.Timestamptz
```

> 注释：`deleted_at` 在 MVP-0 中暂时不用，但提前建列可以让后续软删除不需要大规模补 migration。`created_at / updated_at` 统一用数据库时间和 Prisma `@updatedAt`，方便后续排查任务状态和数据同步问题。

Prisma 里 `VectorDocument.embedding` 先声明为 unsupported：

```prisma
model VectorDocument {
  id         String   @id @default(uuid()) @db.Uuid
  userId     String   @map("user_id") @db.Uuid
  fandomId   String?  @map("fandom_id") @db.Uuid
  novelId    String?  @map("novel_id") @db.Uuid
  sourceType String   @map("source_type") @db.VarChar(32)
  sourceId   String   @map("source_id") @db.Uuid
  chunkText  String   @map("chunk_text")
  embedding  Unsupported("vector(1536)")?
  metadata   Json?
  createdAt  DateTime @default(now()) @map("created_at") @db.Timestamptz
  updatedAt  DateTime @updatedAt @map("updated_at") @db.Timestamptz
  deletedAt  DateTime? @map("deleted_at") @db.Timestamptz

  @@map("vector_documents")
}
```

> 注释：Prisma 当前不能像普通字段一样完整管理 pgvector，因此用 `Unsupported("vector(1536)")` 保留 schema 映射，再用 raw SQL 写入和查询向量。这样既能继续使用 Prisma 管理普通业务表，也不会为了向量检索放弃 pgvector。

执行首个 migration：

```bash
cd apps/api
pnpm prisma migrate dev --name init_schema
cd ../..
```

命令解释：

- `pnpm prisma migrate dev --name init_schema`：根据 `schema.prisma` 生成 SQL migration，并把表结构应用到本地 PostgreSQL。
- `--name init_schema` 是这次迁移的名字，生成的目录名会包含它，方便以后知道这次迁移做了什么。
- 成功标志：`apps/api/prisma/migrations/` 下出现 migration 目录，数据库里出现 users、fandoms、novels 等表。
- 常见问题：如果报数据库连接失败，先确认 `docker compose ps` 中 postgres 正在运行，并检查 `.env` 的 `DATABASE_URL`。

### 3.2 添加 pgvector migration

创建一个 migration，例如：

```bash
cd apps/api
pnpm prisma migrate dev --create-only --name pgvector_indexes
cd ../..
```

命令解释：

- `pnpm prisma migrate dev --create-only --name pgvector_indexes`：只创建 migration 文件，不立即执行。
- 为什么只创建不执行：pgvector 扩展和 ivfflat 索引需要手写 SQL，所以要先生成空 migration，再编辑 `migration.sql`。
- 成功标志：`apps/api/prisma/migrations/` 下出现包含 `pgvector_indexes` 的新目录。

编辑新生成的 `migration.sql`，确保包含：

```sql
CREATE EXTENSION IF NOT EXISTS vector;

CREATE INDEX IF NOT EXISTS vector_documents_embedding_ivfflat_idx
ON vector_documents
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

CREATE INDEX IF NOT EXISTS vector_documents_scope_idx
ON vector_documents (user_id, fandom_id, novel_id, source_type);
```

执行：

```bash
cd apps/api
pnpm prisma migrate dev
pnpm prisma generate
cd ../..
```

命令解释：

- `pnpm prisma migrate dev`：执行刚才手写的 pgvector migration。
- `pnpm prisma generate`：根据最新 `schema.prisma` 生成 Prisma Client。schema 改动后都应该执行它。
- 成功标志：migration 无 error，后端代码可以从 `@prisma/client` 使用最新 model 类型。
- 常见问题：如果 `CREATE EXTENSION vector` 报错，确认 docker 镜像是 `pgvector/pgvector:pg16`，不是普通 `postgres:16`。

> 注释：ivfflat 索引必须在 MVP-0 就创建。否则小数据量时看不出问题，一旦导入 10 万字文本并产生较多向量，RAG 检索延迟会直接影响章节生成体验。`lists = 100` 是本地验证的保守默认值，后续可按数据量调优。

### 3.3 Seed demo user

创建 `apps/api/prisma/seed.ts`：

```ts
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();
const DEMO_USER_ID = "00000000-0000-0000-0000-000000000001";

async function main() {
  await prisma.user.upsert({
    where: { id: DEMO_USER_ID },
    update: {},
    create: {
      id: DEMO_USER_ID,
      email: "demo@local",
      nickname: "Demo User",
      passwordHash: "<dummy-hash>",
    },
  });
}

main().finally(async () => {
  await prisma.$disconnect();
});
```

执行：

```bash
cd apps/api
pnpm seed
cd ../..
```

命令解释：

- `pnpm seed`：执行 `apps/api/package.json` 中的 `seed` 脚本，也就是运行 `tsx prisma/seed.ts`。
- `tsx` 可以直接执行 TypeScript 文件，不需要先手动编译成 JavaScript。
- 成功标志：`users` 表里有 id 为 `00000000-0000-0000-0000-000000000001` 的 demo user。
- 常见问题：如果提示找不到 `seed` 脚本，检查 `apps/api/package.json` 是否包含 `"seed": "tsx prisma/seed.ts"`。

> 注释：用 seed 而不是在应用启动时自动创建 demo user，是为了让数据库初始化过程显式、可重复、可在 CI 或验收脚本中独立执行。`upsert` 保证重复运行不会报错。

### 3.4 后端 common 基础设施

创建 `apps/api/src/common/constants.ts`：

```ts
export const DEMO_USER_ID = "00000000-0000-0000-0000-000000000001";
```

创建 `apps/api/src/common/demo-user.middleware.ts`：

```ts
import { Injectable, NestMiddleware } from "@nestjs/common";
import { DEMO_USER_ID } from "./constants";

declare module "express-serve-static-core" {
  interface Request {
    userId: string;
  }
}

@Injectable()
export class DemoUserMiddleware implements NestMiddleware {
  use(req: any, _res: any, next: () => void) {
    req.userId = DEMO_USER_ID;
    next();
  }
}
```

创建统一错误码 `apps/api/src/common/error-codes.ts`：

```ts
export const ErrorCodes = {
  NOT_FOUND: "NOT_FOUND",
  VALIDATION_FAILED: "VALIDATION_FAILED",
  CONFLICT: "CONFLICT",
  LLM_PROVIDER_ERROR: "LLM_PROVIDER_ERROR",
  IMPORT_PARSE_FAILED: "IMPORT_PARSE_FAILED",
  INTERNAL_ERROR: "INTERNAL_ERROR",
} as const;
```

创建 `HttpErrorFilter`：

- 捕获 `HttpException`
- 返回格式：

```json
{
  "code": "VALIDATION_FAILED",
  "message": "xxx",
  "details": {}
}
```

在 `apps/api/src/main.ts` 中启用：

- `ConfigModule`
- `ValidationPipe({ whitelist: true, transform: true })`
- CORS 允许 `http://localhost:5173`
- 全局异常过滤器
- Swagger 可选，但建议打开 `/docs`

> 注释：统一异常格式很重要。前端只需要识别 `code` 和 `message`，不必针对 NestJS 默认错误、Prisma 错误、业务错误分别写处理逻辑。MVP-0 虽然页面少，但导入和 LLM 调用失败场景多，错误结构不统一会显著增加联调成本。

### 3.5 PrismaService

创建：

```text
apps/api/src/modules/prisma/prisma.module.ts
apps/api/src/modules/prisma/prisma.service.ts
```

`PrismaService` 继承 `PrismaClient`，实现 `OnModuleInit` 调用 `$connect()`，`OnModuleDestroy` 调用 `$disconnect()`。

所有 Service 只通过 `PrismaService` 访问数据库。MVP-0 不实现 Repository，但每个查询都显式带：

```ts
where: {
  userId,
  deletedAt: null,
}
```

> 注释：MVP-0 暂不引入 Repository，是为了减少第一期抽象成本。但所有 Service 显式传 `userId` 和 `deletedAt: null`，相当于提前遵守 Repository 未来会强制执行的约束，避免 MVP-1 大改业务查询。

### 3.6 BullMQ 队列

创建 `apps/api/src/modules/queue/queue.constants.ts`：

```ts
export const IMPORT_QUEUE = "import-queue";
export const EMBEDDING_QUEUE = "embedding-queue";
export const GENERATE_QUEUE = "generate-queue";
```

创建 `QueueModule`，提供：

- `importQueue: Queue`
- `embeddingQueue: Queue`
- `generateQueue: Queue`

Redis 连接来自 `.env`：

```ts
{
  host: process.env.REDIS_HOST ?? 'localhost',
  port: Number(process.env.REDIS_PORT ?? 6379),
}
```

在 `main.ts` 挂载 Bull Board：

```ts
// /admin/queues
```

验收：启动 API 后访问 `http://localhost:3000/admin/queues`。

> 注释：导入、摘要、抽取、生成都可能耗时数十秒到数分钟，不能放在 HTTP 请求里同步等待。BullMQ 让接口快速返回 taskId 或 importTaskId，前端通过轮询观察状态。MVP-0 使用 Bull Board 是为了本地排查卡住的 job，不作为生产管理后台。

### 3.7 Health 接口

创建 `HealthController`：

```ts
@Controller("health")
export class HealthController {
  @Get()
  get() {
    return { ok: true };
  }
}
```

验收：

```bash
pnpm --filter api dev
curl http://localhost:3000/health
```

> 注释：`/health` 是最小可观测性。它不能证明数据库、Redis、LLM 都正常，但可以证明 API 进程启动和路由注册正常。后续 smoke 脚本和本地启动检查都可以先打这个端点。

---

## 4. S1：基础 CRUD 模块

### 4.1 Fandom 模块

文件：

```text
apps/api/src/modules/fandom/
├── dto/create-fandom.dto.ts
├── fandom.controller.ts
├── fandom.module.ts
└── fandom.service.ts
```

DTO：

```ts
export class CreateFandomDto {
  @IsString()
  @MaxLength(128)
  name!: string;

  @IsOptional()
  @IsIn(["novel", "anime", "game", "film", "other"])
  type?: string = "novel";

  @IsOptional()
  @IsString()
  description?: string;
}
```

Controller：

- `POST /fandoms`
- `GET /fandoms`
- `GET /fandoms/:id`

Service 方法：

- `create(userId: string, dto: CreateFandomDto)`
- `list(userId: string)`
- `getById(userId: string, id: string)`

实现要求：

- `create` 写入 `userId`
- `list` 按 `createdAt desc`
- `getById` 查不到抛 404
- 所有查询过滤 `deletedAt: null`

> 注释：Fandom 是整个闭环的根对象。先实现 Fandom CRUD，是因为导入、候选实体、Novel 都需要依附 fandom。MVP-0 不做编辑和删除，是为了避免引入向量一致性、级联更新等 MVP-1 范围问题。

### 4.2 Novel 模块

文件：

```text
apps/api/src/modules/novel/
├── dto/create-novel.dto.ts
├── novel.controller.ts
├── novel.module.ts
└── novel.service.ts
```

DTO：

- `title`: 必填，128 字以内
- `fandomId`: 必填，uuid
- `type`: 默认 `fanfic`
- `fanficType`: 默认 `if`
- `description`, `divergencePoint`, `tone`: 可选

Controller：

- `POST /novels`
- `GET /novels`
- `GET /novels/:id`

Service 方法：

- `create(userId, dto)`
- `list(userId)`
- `getById(userId, id)`

`create` 必须使用 Prisma transaction：

1. 校验 fandom 属于当前 demo user。
2. 创建 `novels` 行，`status = 'writing'`。
3. 创建默认 `volumes` 行：
   - `title = '正文卷'`
   - `orderIndex = 0`
4. 创建默认 `writing_styles` 行：
   - `name = '默认风格'`
   - 其他文本字段为空字符串。
5. 返回 novel，包含 volume 和 writingStyle。

> 注释：创建 Novel 时同步创建默认 Volume 和 WritingStyle，是为了让章节编辑器和 Prompt 拼装不需要处理“小说存在但没有卷/风格”的空状态。这个事务保证 Novel 的最小可用上下文一次性建立，失败时整体回滚。

### 4.3 Chapter 模块基础 CRUD

文件：

```text
apps/api/src/modules/chapter/
├── dto/create-chapter.dto.ts
├── dto/update-chapter.dto.ts
├── chapter.controller.ts
├── chapter.module.ts
└── chapter.service.ts
```

Controller：

- `POST /novels/:id/chapters`
- `GET /novels/:id/chapters`
- `GET /chapters/:id`
- `PUT /chapters/:id`

`CreateChapterDto`：

- `title`: 默认可由前端传 `第 N 章`
- `outline`: 可选

创建章节逻辑：

1. 查 novel，确认 `userId`。
2. 查默认 volume。
3. 计算下一个 `chapterNo = max(chapterNo) + 1`，没有则 1。
4. 创建 chapter：
   - `status = 'draft'`
   - `wordCount = 0`

`UpdateChapterDto` 支持全量更新：

- `title`
- `outline`
- `content`
- `summary`
- `goal`
- `extraNotes`
- `appearingCharacterIds`

注意：设计文档里的 `chapters` 表没有显式列出 `goal`、`extra_notes`、`appearing_character_ids`，但章节生成 Prompt 需要这些字段。MVP-0 推荐直接在 `chapters` 表增加：

- `goal text`
- `extra_notes text`
- `appearing_character_ids uuid[] default '{}'`

否则只能把这些内容塞进 `outline`，会降低可维护性。

> 注释：`goal`、`extra_notes`、`appearing_character_ids` 是从 Prompt 需求反推出来的字段。虽然原设计表未单列，但章节生成需要稳定读取这些结构化输入。提前加列比把它们混进 outline 更清晰，也便于前端表单和后续 Prompt 调优。

---

## 5. S2：LLM、Prompt、对象存储

### 5.1 LLM 模块

文件：

```text
apps/api/src/modules/llm/
├── llm.module.ts
├── llm.service.ts
└── llm.types.ts
```

`LlmService` 方法：

```ts
complete(input: {
  system?: string;
  prompt: string;
  temperature?: number;
  maxTokens?: number;
}): Promise<{
  text: string;
  model: string;
  tokenUsage?: { prompt?: number; completion?: number; total?: number };
}>;

embed(text: string): Promise<number[]>;
```

实现要求：

- 使用 `openai` SDK。
- `baseURL`、`apiKey`、`model`、`embeddingModel` 全部从 `.env` 读取。
- `complete` 非流式。
- 出错时抛 `BadGatewayException`，错误码映射为 `LLM_PROVIDER_ERROR`。

> 注释：LLM 服务失败本质上是上游服务失败，映射成 502 比 500 更准确。MVP-0 不做 Provider 抽象，但把 `complete` 和 `embed` 收敛到 `LlmService`，后续替换 DeepSeek、Qwen 或 OpenAI 兼容网关时只改这一层。

创建脚本 `apps/api/src/scripts/llm-ping.ts`：

```ts
// 调用 complete({ prompt: '请回复 pong' }) 并打印结果
```

验收：

```bash
pnpm --filter api llm:ping
```

### 5.2 Prompt 文件

创建：

```text
apps/api/src/prompts/import/summarize.txt
apps/api/src/prompts/import/extract.txt
apps/api/src/prompts/chapter/generate.txt
```

`summarize.txt`：

```text
你是一名小说摘要助手。请为下面的原作章节生成 200-400 字的中文摘要。
要求：
1. 列出本章出现的主要人物（用顿号分隔）。
2. 概括 3-5 个关键事件。
3. 提及主要地点。
4. 不要复述对话，不带主观评价。
5. 用第三人称、过去时。

【章节正文】
{{content}}
```

`extract.txt`：

```text
你是一名小说设定分析师。请从下面的原作章节中抽取候选实体，输出 JSON：
{
  "characters": [
    {
      "name": "...",
      "aliases": ["..."],
      "identity": "...",
      "personality": "...",
      "appearance": "...",
      "evidence": "本章原文证据片段（不超过80字）",
      "confidence": 0.0
    }
  ],
  "world_settings": [
    {
      "category": "location|organization|power_system|item|rule|history|other",
      "name": "...",
      "description": "...",
      "rules": "...",
      "evidence": "...",
      "confidence": 0.0
    }
  ],
  "events": [
    {
      "name": "...",
      "summary": "...",
      "evidence": "...",
      "confidence": 0.0
    }
  ]
}
要求：
- 只抽取在本章中有明确文本证据的实体。
- 配角和路人不需要抽取。
- 不要编造原文中没有的设定。
- 只输出 JSON，不要输出 Markdown 代码块。

【章节正文】
{{content}}
```

`generate.txt` 按 [0001-design.md §6.5](0001-design.md#65-章节生成-prompt关键) 落盘，保留所有段落。实现 Prompt 渲染时，空字段对应的整段要省略。

创建 `apps/api/src/prompts/prompt-loader.ts`：

- 使用 `readFileSync` 读取三个文件。
- 导出 `PROMPTS.summarize`、`PROMPTS.extract`、`PROMPTS.generate`。

创建 `apps/api/src/prompts/render-template.ts`：

- MVP-0 可用简单 `replaceAll('{{content}}', value)`。
- 章节生成 Prompt 建议不用通用模板引擎，直接由 `PromptBuilderService` 拼字符串，避免 Handlebars 依赖和空段落处理复杂化。

> 注释：Prompt 放文件而不是硬编码在 service 中，是为了让 Prompt 变更可以像代码一样被 review。MVP-0 不做版本 registry，因为当前只有一个版本；但目录结构已经按用途拆开，MVP-1 增加版本管理时迁移成本低。

### 5.3 MinIO Storage 模块

文件：

```text
apps/api/src/modules/storage/
├── storage.module.ts
└── storage.service.ts
```

`StorageService` 方法：

```ts
putObject(input: {
  buffer: Buffer;
  objectName: string;
  contentType?: string;
}): Promise<{ objectName: string }>;

getObject(objectName: string): Promise<Buffer>;

ensureBucket(): Promise<void>;
```

实现要求：

- 启动时检查 bucket，不存在则创建。
- 上传 objectName 格式：

```text
imports/{userId}/{fandomId}/{importTaskId}/{originalFileName}
```

- MVP-0 文件大小限制在 Controller 层做：`5 MB`。

> 注释：原文可能很长，不适合直接存在 PostgreSQL 的普通字段里。MinIO 存原始上传文件，数据库只记录任务状态和对象 key。这样可以减少数据库膨胀，也保留重新处理导入任务的可能性。

---

## 6. S2：导入流水线

### 6.1 Import 模块 API

文件：

```text
apps/api/src/modules/import/
├── import.controller.ts
├── import.module.ts
├── import.service.ts
└── text-processing.service.ts
```

Controller：

- `POST /fandoms/:id/imports`
- `GET /imports/:id`
- `GET /imports/:id/chapters`
- `GET /imports/:id/candidates`

`POST /fandoms/:id/imports`：

1. 使用 `FileInterceptor('file')` 接收 multipart。
2. 校验文件存在。
3. 校验 `file.size <= 5 * 1024 * 1024`。
4. 校验 fandom 属于当前 user。
5. 创建 `import_tasks`：
   - `sourceType = 'txt'`
   - `status = 'pending'`
   - `progress = 0`
6. 上传原文件到 MinIO。
7. 将 MinIO object key 写到 `import_tasks`。设计表未列 object key，推荐加列：
   - `object_key varchar(512)`
8. 投递 import queue：

```ts
await importQueue.add("process-import", { importTaskId, userId });
```

9. 返回 import task。

> 注释：上传接口只负责“接收文件、落对象存储、创建任务、投递队列”，不直接切章和调 LLM。这样 HTTP 请求不会因为 LLM 慢或文本大而超时，前端也能通过 import task 统一展示进度。

### 6.2 TextProcessingService

方法：

```ts
cleanText(raw: string): string;
splitChapters(text: string): Array<{
  chapterNo: number;
  title: string;
  content: string;
  wordCount: number;
}>;
```

`cleanText` 规则：

- 去 UTF-8 BOM。
- `\r\n`、`\r` 统一为 `\n`。
- 全角空格 `\u3000` 替换为空格。
- 连续 3 个及以上空行压缩为 2 个换行。
- trim 首尾空白。

`splitChapters` 规则按优先级：

1. 行首匹配 `^第[零一二三四五六七八九十百千万0-9]+章`。
2. 行首匹配 `^Chapter\s+\d+`，忽略大小写。
3. Markdown 一级标题 `^#\s+`。
4. 空行 + 短行标题：长度不超过 30，且前后有空行。
5. 兜底滑窗：每段约 6000 字，优先在句号、问号、感叹号处切。

实现建议：

- 先按行扫描，收集标题行 index。
- 如果标题数 >= 2，则按标题切。
- 如果标题数 < 2，再尝试短行标题。
- 如果仍然不足，则滑窗。
- 每章 `content` 不包含下一章标题。
- `title` 无法识别时用 `第${chapterNo}章`。

单测必须覆盖：

- 中文章节标题
- `Chapter 1`
- Markdown `# 第一章`
- 短行标题
- 无标题长文本滑窗

> 注释：章节切分优先用明确标题规则，是为了最大程度保留原作章节结构；短行标题用于兼容没有“第 N 章”格式的文本；滑窗是兜底，保证任何 txt 都能进入后续摘要/抽取流程。单测覆盖这些规则，是因为切分错误会污染整个知识库和 RAG。

### 6.3 ImportWorker

文件：

```text
apps/api/src/workers/import-worker.ts
```

Worker 处理 job name：`process-import`。

主方法：

```ts
processImport(importTaskId: string, userId: string): Promise<void>
```

阶段 1：cleaning

1. `import_tasks.status = 'processing'`
2. `stage = 'cleaning'`
3. 从 MinIO 读取 object。
4. `cleanText`。
5. `progress = 10`

阶段 2：splitting

1. `stage = 'splitting'`
2. `splitChapters`
3. 若结果为空，抛 `IMPORT_PARSE_FAILED`
4. 批量插入 `imported_chapters`
   - `status = 'pending'`
   - `chapterNo`
   - `title`
   - `content`
   - `wordCount`
5. `progress = 25`

阶段 3：summarizing

1. `stage = 'summarizing'`
2. 串行遍历 imported chapters。
3. 对每章调用 summarize prompt。
4. 写 `imported_chapters.summary`
5. 写 `imported_chapters.status = 'summarized'`
6. 每次 LLM 调用写一条 `generation_tasks`：
   - `taskType = 'SUMMARY'`
   - `status = 'success'` 或 `failed`
   - `promptText`
   - `resultText`
   - `tokenUsage`
7. 按章节进度更新 `progress = 25..55`

阶段 4：extracting

1. `stage = 'extracting'`
2. 串行遍历 imported chapters。
3. 调 extract prompt。
4. 解析 JSON。
5. JSON 解析失败时，追加提示“上一次输出不是合法 JSON，请只输出修正后的 JSON”，重试 1 次。
6. 将 characters、world_settings、events 写入 `extraction_candidates`。
7. `entityType` 分别为 `CHARACTER`、`WORLD_SETTING`、`EVENT`。
8. `contentJson` 保存完整对象。
9. `confidence` 从模型输出读取，缺失则填 `0.5`。
10. `status = 'pending'`
11. 更新 `progress = 55..80`

阶段 5：embedding

1. `stage = 'embedding'`
2. 对每个 imported chapter summary 投递 embedding job：

```ts
await embeddingQueue.add("embed-source", {
  userId,
  fandomId,
  novelId: null,
  sourceType: "IMPORTED_CHAPTER_SUMMARY",
  sourceId: importedChapter.id,
  chunkText: importedChapter.summary,
  metadata: { chapterNo, title },
});
```

3. MVP-0 为了流程简单，可以在 import worker 中 `await` embedding service 直接写入，也可以投递队列。若投递队列，import task 可在投递完成后先进入 reviewing。
4. `progress = 100`
5. `status = 'reviewing'`

失败处理：

- 任意阶段抛错：
  - `import_tasks.status = 'failed'`
  - `error_message = error.message`
  - 保留当前 `stage`

> 注释：import worker 按阶段顺序更新 `stage` 和 `progress`，前端才能给用户一个可解释的进度，而不是只有“处理中”。MVP-0 故意串行摘要和抽取，是为了降低 Provider 限流、JSON 解析失败和任务并发调试的复杂度；性能不足的问题留到 MVP-1 优化。

### 6.4 EmbeddingWorker

文件：

```text
apps/api/src/workers/embedding-worker.ts
```

job name：`embed-source`。

方法：

```ts
embedSource(input: {
  userId: string;
  fandomId?: string | null;
  novelId?: string | null;
  sourceType: string;
  sourceId: string;
  chunkText: string;
  metadata?: Record<string, unknown>;
}): Promise<void>
```

实现：

1. 调 `LlmService.embed(chunkText)`。
2. 使用 `$executeRaw` 写入 vector：

```sql
INSERT INTO vector_documents
(id, user_id, fandom_id, novel_id, source_type, source_id, chunk_text, embedding, metadata, created_at, updated_at)
VALUES
(gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7::vector, $8::jsonb, now(), now())
```

3. TypeScript 中将 `number[]` 转成 pgvector 字符串：

```ts
const vector = `[${embedding.join(",")}]`;
```

> 注释：向量写入使用 raw SQL 是因为 Prisma 对 pgvector 的支持有限。把 embedding 逻辑独立成 worker/service，是为了让 imported summary、character、world setting、chapter summary 都复用同一条向量化路径，避免不同来源写入格式不一致。

### 6.5 Extraction 审核模块

文件：

```text
apps/api/src/modules/extraction/
├── extraction.controller.ts
├── extraction.module.ts
└── extraction.service.ts
```

Controller：

- `POST /candidates/:id/approve`
- `POST /candidates/:id/reject`

`approve(userId, candidateId)`：

1. 查 candidate：
   - `userId`
   - `status = 'pending'`
2. 若 `entityType = 'CHARACTER'`：
   - 从 `contentJson` 取 `name`、`aliases`、`identity`、`personality`、`appearance`
   - 检查同 fandom、`novelId = null`、同名人物是否存在。
   - 存在则返回 409。
   - 创建 `characters`，`sourceType = 'imported'`。
3. 若 `entityType = 'WORLD_SETTING'`：
   - 从 `contentJson` 取 `category`、`name`、`description`、`rules`
   - 检查同 fandom、`novelId = null`、同名世界观是否存在。
   - 存在则返回 409。
   - 创建 `world_settings`，`sourceType = 'imported'`。
4. 若 `entityType = 'EVENT'`：
   - MVP-0 不建正式 event 表。
   - 推荐只把 candidate 标为 `approved`，不创建实体，也不 embedding。
5. 更新 candidate：
   - `status = 'approved'`
   - `targetEntityId = created.id`
6. 对 characters / world_settings 投递 embedding：
   - sourceType `CHARACTER` 或 `WORLD_SETTING`
   - chunkText 拼成适合检索的中文描述。

`reject(userId, candidateId)`：

1. 查 pending candidate。
2. 更新 `status = 'rejected'`。
3. 调 `maybeCompleteImportTask(importTaskId)`：
   - 若该 import task 下没有 pending candidate，则 `import_tasks.status = 'completed'`。

> 注释：AI 抽取结果必须经过人工审核再进入正式人物/世界观表。这样能防止模型幻觉直接污染 RAG。MVP-0 不做“编辑后接受”和“合并到已有实体”，因此同名冲突直接 409，让用户拒绝候选即可。

---

## 7. S3：RAG、章节生成、完结回灌

### 7.1 RAG Service

文件：

```text
apps/api/src/modules/rag/
├── rag.module.ts
├── rag.service.ts
└── prompt-builder.service.ts
```

`RagService.retrieveForChapter(userId, chapterId)` 返回：

```ts
{
  relevantCharacters: VectorHit[];
  relevantWorldSettings: VectorHit[];
  relevantOriginalSummaries: VectorHit[];
  relevantChapterSummaries: VectorHit[];
  recentChapterSummaries: Array<{ chapterNo: number; title: string; summary: string }>;
}
```

构造 query：

```text
{chapter.title}
{chapter.outline}
{chapter.goal}
{chapter.extraNotes}
出场人物：{appearing character names}
```

检索步骤：

1. 调 embedding 得到 query vector。
2. 四路检索：
   - `CHARACTER` top 5
   - `WORLD_SETTING` top 5
   - `IMPORTED_CHAPTER_SUMMARY` top 5
   - `CHAPTER_SUMMARY` top 8，必须过滤当前 novelId
3. SQL 使用 cosine：

```sql
SELECT id, source_type, source_id, chunk_text, metadata,
       embedding <=> $1::vector AS distance
FROM vector_documents
WHERE user_id = $2::uuid
  AND deleted_at IS NULL
  AND embedding IS NOT NULL
  AND source_type = $3
  AND (
    fandom_id = $4::uuid
    OR novel_id = $5::uuid
  )
ORDER BY embedding <=> $1::vector
LIMIT $6;
```

4. 最近 3 章摘要不用向量，直接查：

```ts
where: {
  novelId,
  chapterNo: { lt: current.chapterNo },
  status: 'final',
  summary: { not: null },
}
orderBy: { chapterNo: 'desc' }
take: 3
```

> 注释：RAG 同时使用“向量召回”和“最近 3 章直拉”。向量召回负责找到语义相关内容，最近章节直拉负责保证连续剧情不会遗忘。两者都需要，因为第二章生成引用第一章事件是 MVP-0 DoD 的关键验证点。

### 7.2 PromptBuilderService

方法：

```ts
buildGeneratePrompt(input: {
  novel: Novel;
  style: WritingStyle;
  chapter: Chapter;
  appearingCharacters: Character[];
  rag: RagResult;
  wordTarget?: number;
}): string;
```

实现要求：

- 字段为空时整段省略。
- 对用户可输入字段做硬截断：
  - `outline <= 4000`
  - `goal <= 1000`
  - `extraNotes <= 1000`
  - 单个人物 RAG 文本 <= 800
  - 单个世界观 RAG 文本 <= 800
  - 单个摘要 <= 800
- 默认 `wordTarget = 3000`
- 最终 prompt 不记录到普通日志，只写 `generation_tasks.promptText`。

> 注释：PromptBuilder 独立出来，是为了让“检索结果如何进入 Prompt”可以单测。字段硬截断不是完整 token 预算算法，但能避免用户输入过长导致 Provider 上下文溢出，是 MVP-0 的最低成本防线。

### 7.3 Chapter generate API

在 `ChapterController` 增加：

- `POST /chapters/:id/generate`
- `POST /chapters/:id/complete`

`POST /chapters/:id/generate`：

1. 查 chapter，校验属于当前 user。
2. 创建 `generation_tasks`：
   - `taskType = 'GENERATE_CHAPTER'`
   - `status = 'pending'`
   - `chapterId`
   - `novelId`
3. 投递 generate queue：

```ts
await generateQueue.add("generate-chapter", { taskId, userId, chapterId });
```

4. 返回 `{ taskId }`。

> 注释：生成接口返回 taskId，而不是直接返回正文，是因为单章生成可能接近 180 秒。HTTP 长连接等待会让前端、代理和浏览器都更容易超时；task 模型也能保留 token 用量、错误信息和生成结果，便于验收和排查。

### 7.4 GenerateWorker

文件：

```text
apps/api/src/workers/generate-worker.ts
```

处理两个 job：

- `generate-chapter`
- `complete-chapter`

`generateChapter(taskId, userId, chapterId)`：

1. 将 task 更新为 `running`。
2. 拉取 chapter、novel、writingStyle。
3. 拉出 `appearingCharacterIds` 对应人物。
4. 调 `RagService.retrieveForChapter`。
5. 调 `PromptBuilderService.buildGeneratePrompt`。
6. 调 `LlmService.complete`。
7. 更新 chapter：
   - `content = llm.text`
   - `wordCount = countChineseLikeChars(llm.text)`
   - `status = 'generated'`
8. 更新 task：
   - `status = 'success'`
   - `promptText`
   - `resultText`
   - `modelName`
   - `tokenUsage`

失败处理：

- task `status = 'failed'`
- `errorMessage = error.message`
- 不覆盖原 `chapter.content`

`countChineseLikeChars` MVP-0 简单实现：

```ts
text.replace(/\s/g, "").length;
```

> 注释：生成 worker 失败时不覆盖原正文，是为了避免用户已有内容被一次失败调用清空。MVP-0 自动覆盖只发生在成功生成后；“应用/丢弃候选稿”的更细体验留到后续版本。

### 7.5 GenerationTask 查询

文件：

```text
apps/api/src/modules/task/
├── task.controller.ts
├── task.module.ts
└── task.service.ts
```

Controller：

- `GET /generation-tasks/:id`

返回：

```ts
{
  id: string;
  taskType: string;
  status: string;
  modelName?: string;
  resultText?: string;
  tokenUsage?: unknown;
  errorMessage?: string;
  createdAt: string;
  updatedAt: string;
}
```

> 注释：GenerationTask 是前端轮询和后端审计的共同载体。即使 MVP-0 不做生成历史页面，也必须保留这个端点，否则用户无法知道生成是否失败、失败原因是什么。

### 7.6 完成本章

`POST /chapters/:id/complete`：

1. 查 chapter。
2. 若 content 为空，返回 400。
3. 创建 `generation_tasks`：
   - `taskType = 'GENERATE_CHAPTER_SUMMARY'`
   - `status = 'pending'`
4. 投递：

```ts
await generateQueue.add("complete-chapter", { taskId, userId, chapterId });
```

5. 返回 `{ taskId }`。

`completeChapter(taskId, userId, chapterId)`：

1. task `running`。
2. 用摘要 prompt 生成 200-400 字章节摘要。
3. 更新 chapter：
   - `summary`
   - `status = 'final'`
4. 写入 vector_documents：
   - `sourceType = 'CHAPTER_SUMMARY'`
   - `sourceId = chapter.id`
   - `novelId = chapter.novelId`
   - `fandomId = novel.fandomId`
   - `chunkText = summary`
   - `metadata = { chapterNo, title }`
5. task `success`。

> 注释：完结章节时立即生成摘要并写入向量库，是 RAG 闭环的核心。否则第二章生成只能看到原作知识库，看不到用户刚写完的第一章，自然无法满足“引用前文事件”的 DoD。

---

## 8. S4：前端实现

### 8.1 基础配置

`apps/web/src/api/client.ts`：

```ts
import axios from "axios";

export const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL ?? "http://localhost:3000",
});
```

创建 `apps/web/.env.example`：

```bash
VITE_API_BASE_URL=http://localhost:3000
```

`main.tsx`：

- 创建 `QueryClient`
- 包裹 `QueryClientProvider`
- 使用 `BrowserRouter`
- 挂载 toast provider

> 注释：前端用 TanStack Query 是因为 MVP-0 几乎所有状态都来自 REST 接口和后台任务轮询。它能统一处理 loading、error、缓存刷新和 refetchInterval，避免手写大量 useEffect 状态机。

`routes.tsx` 路由：

- `/`
- `/fandoms`
- `/fandoms/:id`
- `/novels`
- `/novels/:id`
- `/novels/:id/chapters/:cid`

### 8.2 API hooks

创建文件：

```text
apps/web/src/api/fandoms.ts
apps/web/src/api/imports.ts
apps/web/src/api/novels.ts
apps/web/src/api/chapters.ts
apps/web/src/api/tasks.ts
```

至少实现 hooks：

- `useFandoms()`
- `useCreateFandom()`
- `useFandom(id)`
- `useCreateImport(fandomId)`
- `useImportTask(importId, enabled)`
- `useImportChapters(importId)`
- `useCandidates(importId, filters)`
- `useApproveCandidate()`
- `useRejectCandidate()`
- `useNovels()`
- `useCreateNovel()`
- `useNovel(id)`
- `useChapters(novelId)`
- `useCreateChapter(novelId)`
- `useChapter(chapterId)`
- `useUpdateChapter(chapterId)`
- `useGenerateChapter(chapterId)`
- `useCompleteChapter(chapterId)`
- `useGenerationTask(taskId, enabled)`

轮询：

- import task：`refetchInterval: status processing/pending ? 2000 : false`
- generation task：`refetchInterval: pending/running ? 2000 : false`

> 注释：MVP-0 选择轮询而不是 SSE，是为了减少后端连接管理和前端流式状态处理。2 秒轮询对本地 dogfood 足够，且任务状态都已落库，刷新页面后也能恢复进度。

### 8.3 布局

文件：

```text
apps/web/src/components/app-layout.tsx
```

布局：

- 顶栏：产品名 `Fiction Studio`，右侧 `Demo User`
- 左侧导航：
  - 工作台
  - 知识库
  - 我的小说
- 主区渲染 `<Outlet />`

> 注释：布局只保留主导航和 demo 用户名，避免把精力花在登录、设置、仪表盘统计等非 MVP-0 功能上。导航结构对应三个核心对象：知识库、小说、章节。

### 8.4 工作台 `/`

文件：

```text
apps/web/src/pages/dashboard-page.tsx
```

展示：

- “新建知识库”按钮
- “新建小说”按钮
- 最近 fandom 列表
- 最近 novel 列表

MVP-0 不做统计图。

> 注释：工作台只提供入口，不做复杂运营面板。MVP-0 的目标是跑通创作闭环，统计图、趋势、历史任务都不会帮助验证核心技术路径。

### 8.5 知识库列表 `/fandoms`

文件：

```text
apps/web/src/pages/fandoms-page.tsx
```

功能：

- 卡片列表展示 fandom name、type、createdAt。
- 新建对话框：
  - name
  - type select
  - description textarea
- 创建成功后跳转 `/fandoms/:id`。

> 注释：创建后直接进入详情，是为了缩短“建知识库 -> 上传原作”的路径。MVP-0 不做多步骤创建向导，减少用户在闭环验证前的输入成本。

### 8.6 Fandom 详情 `/fandoms/:id`

文件：

```text
apps/web/src/pages/fandom-detail-page.tsx
```

区域 1：上传

- `<input type="file" accept=".txt,text/plain">`
- 上传按钮
- 上传中禁用按钮
- 上传完成后保存 `importTaskId`

区域 2：导入进度

- 展示 status、stage、progress。
- 使用 progress 组件。
- `reviewing` 或 `completed` 后展示审核区。

区域 3：候选审核

- Tabs：
  - 人物：`CHARACTER`
  - 世界观：`WORLD_SETTING`
  - 事件：`EVENT`
- 每行展示：
  - name
  - confidence
  - evidence 或 summary
  - 接受
  - 拒绝
- EVENT 的接受按钮可以隐藏或置灰，并提示 MVP-0 不入库。

区域 4：已入库实体表

MVP-0 设计未列 characters/world_settings 列表端点，但前端需要“接受后实体表实时刷新”。因此后端应补两个只读端点：

- `GET /fandoms/:id/characters`
- `GET /fandoms/:id/world-settings`

这两个端点只做列表，不做 CRUD。

> 注释：Fandom 详情把上传、进度、审核和实体查看放在一个页面，是为了减少 MVP-0 的路由和状态同步复杂度。补只读实体列表端点，是前端最小可用所需，但仍避免提前实现完整实体 CRUD。

### 8.7 我的小说 `/novels`

文件：

```text
apps/web/src/pages/novels-page.tsx
```

功能：

- novel 列表
- 新建对话框：
  - title
  - fandomId select
  - fanficType select
  - tone input
  - description textarea
- 创建成功跳转 `/novels/:id`。

> 注释：Novel 创建只要求 title 和 fandomId，是对 MVP-1 七步向导的有意收缩。当前阶段只需要建立小说和原作知识库的关联，让章节生成能拿到 fandom 范围内的 RAG 内容。

### 8.8 小说空间 `/novels/:id`

文件：

```text
apps/web/src/pages/novel-detail-page.tsx
```

展示：

- novel 标题、状态、关联 fandom
- 章节列表：
  - chapterNo
  - title
  - status
  - wordCount
- 新建章节按钮。
- 点击章节跳转 `/novels/:id/chapters/:cid`。

> 注释：小说空间只承担章节索引和入口职责。卷管理、风格编辑、设定面板都暂时不做，避免在章节生成闭环前扩张页面范围。

### 8.9 章节编辑器

文件：

```text
apps/web/src/pages/chapter-editor-page.tsx
```

布局：

```text
左侧：章节列表，固定宽度 260px
右侧：编辑区，自上而下
  标题 input
  大纲 textarea
  出场人物多选
  本章目标 textarea
  额外要求 textarea
  生成按钮
  正文 textarea
  保存按钮
  完成本章按钮
```

出场人物多选需要人物列表。后端已补 `GET /fandoms/:id/characters`，前端从 novel 详情得到 fandomId 后加载。

按钮行为：

- 保存：
  - 调 `PUT /chapters/:id`
  - 保存 title、outline、content、goal、extraNotes、appearingCharacterIds
- 生成本章正文：
  - 先自动保存当前表单。
  - 调 `POST /chapters/:id/generate`。
  - 保存 taskId。
  - 轮询 `GET /generation-tasks/:id`。
  - success 后重新拉取 chapter，正文 textarea 被新 content 覆盖。
  - failed 后显示错误。
- 完成本章：
  - 先保存当前正文。
  - 调 `POST /chapters/:id/complete`。
  - 轮询 task。
  - success 后重新拉取 chapter，状态应为 final。

UI 状态：

- task pending/running 时禁用生成和完成按钮。
- 生成超过 180 秒时显示警告文本。
- `chapter.status === 'final'` 时正文仍允许编辑，但完成按钮禁用，MVP-1 再做快照和冲突。

> 注释：章节编辑器使用 textarea 而不是 TipTap，是为了降低实现风险。MVP-0 要验证的是 RAG 和生成链路，不是富文本体验。显式保存也比自动保存更简单，避免引入版本冲突和快照表。

---

## 9. 测试与验收脚本

### 9.1 单元测试

必须覆盖：

| 文件                              | 测试点                                             |
| --------------------------------- | -------------------------------------------------- |
| `text-processing.service.spec.ts` | BOM、换行、空行、章节标题、滑窗                    |
| `prompt-builder.service.spec.ts`  | 空段落省略、字段截断、RAG 拼接                     |
| `rag.service.spec.ts`             | SQL 参数、sourceType top-k、novel/fandom 过滤      |
| `extraction.service.spec.ts`      | approve character、approve world、reject、冲突 409 |
| `chapter.service.spec.ts`         | 新建 chapterNo 自增、PUT wordCount                 |

执行：

```bash
pnpm --filter api test:cov
```

命令解释：

- `pnpm --filter api test:cov`：只在 API 项目中运行测试覆盖率脚本。
- `--filter api` 表示目标是 `apps/api` 这个 workspace 包。
- `test:cov` 对应 `apps/api/package.json` 里的 `jest --coverage`。
- 成功标志：终端显示测试通过，并输出覆盖率表；项目中出现 `coverage/` 目录。

MVP-0 要求覆盖率 >= 40%。如果时间不足，优先保证 `cleaning / splitting / RAG / prompt 拼装 / 状态机`。

> 注释：测试优先覆盖“错了会污染闭环”的代码：切章会影响知识库质量，Prompt 拼装会影响生成质量，RAG 过滤会影响数据边界，状态机会影响前端进度。页面样式和简单 CRUD 的测试优先级较低。

### 9.2 导入 smoke 脚本

创建 `scripts/smoke-import.ps1`：

流程：

1. `POST /fandoms`
2. `POST /fandoms/:id/imports` 上传 `specs/demo.txt`
3. 每 2 秒轮询 `GET /imports/:id`
4. 等到 `reviewing`
5. 调 `GET /imports/:id/candidates?status=pending`
6. 输出候选数量
7. approve 前 3 个人物和前 3 个世界观

验收标准：

- import task 最终为 `reviewing` 或 `completed`
- candidates 总数 >= 10
- vector_documents 中有 imported summary 向量

> 注释：smoke 脚本不是替代单测，而是验证跨模块集成：HTTP、MinIO、PostgreSQL、Redis、LLM、worker 是否能串起来。导入链路问题通常不在单个函数里，必须用脚本跑全链路才能发现。

### 9.3 生成 smoke 脚本

创建 `scripts/smoke-generation.ps1`：

流程：

1. 创建 novel，关联上一步 fandom。
2. 创建第 1 章。
3. PUT 第 1 章：
   - title
   - outline
   - goal
   - appearingCharacterIds
4. POST generate。
5. 轮询 task 到 success。
6. POST complete。
7. 轮询 complete task 到 success。
8. 创建第 2 章。
9. POST generate。
10. 检查第 2 章正文包含第 1 章关键字。

验收标准：

- 第 1 章生成 <= 180 秒。
- 第 1 章完成后 `status = final`。
- `vector_documents` 有 `CHAPTER_SUMMARY`。
- 第 2 章正文能引用第 1 章事件。

> 注释：生成 smoke 脚本直接对应 MVP-0 的核心 DoD。只生成第一章不能证明 RAG 回灌有效；必须完成第一章、生成摘要和向量，再生成第二章，才能证明“用户已写内容 -> 未来生成上下文”的闭环成立。

---

## 10. 启动顺序

首次启动：

```bash
corepack enable pnpm
pnpm install
Copy-Item .env.example .env
docker compose up -d
pnpm --filter api prisma:generate
pnpm --filter api prisma:migrate --name init
pnpm --filter api seed
pnpm dev
```

命令解释：

- `corepack enable pnpm`：确保本机可以使用 pnpm。
- `pnpm install`：安装根项目、API、Web、shared 包的所有依赖。
- `Copy-Item .env.example .env`：复制本地配置文件。macOS / Linux 可用 `cp .env.example .env`。
- `docker compose up -d`：启动 PostgreSQL、Redis、MinIO。
- `pnpm --filter api prisma:generate`：执行 API 项目里的 Prisma Client 生成脚本，保证 TypeScript 能识别数据库模型。
- `pnpm --filter api prisma:migrate --name init`：执行 API 项目里的 Prisma migration 脚本，创建或更新数据库表。这里的 `--name init` 会传给 Prisma，作为迁移名称。
- `pnpm --filter api seed`：写入 demo user。
- `pnpm dev`：执行根目录 dev 脚本，通常会同时启动 API 和 Web。
- 成功标志：Web、API health、BullMQ Dashboard、MinIO Console 都能打开。

日常启动：

```bash
docker compose up -d
pnpm dev
```

命令解释：

- 日常启动不需要重复 migrate 和 seed，除非 schema 或 seed 文件发生变化。
- `docker compose up -d` 确保依赖服务已启动。
- `pnpm dev` 启动应用代码。

本地入口：

- Web: `http://localhost:5173`
- API health: `http://localhost:3000/health`
- API docs: `http://localhost:3000/docs`
- BullMQ Dashboard: `http://localhost:3000/admin/queues`
- MinIO Console: `http://localhost:9001`

> 注释：启动顺序先依赖、再 migration、再 seed、最后应用。这样可以把“数据库没建好”和“应用代码有 bug”分开排查。日常启动不重复 migration，避免开发中误触 schema 变更。

---

## 11. API 清单

MVP-0 必须实现：

| 方法 | 路径                          | 说明                     |
| ---- | ----------------------------- | ------------------------ |
| POST | `/fandoms`                    | 新建 Fandom              |
| GET  | `/fandoms`                    | Fandom 列表              |
| GET  | `/fandoms/:id`                | Fandom 详情              |
| GET  | `/fandoms/:id/characters`     | 人物列表，只读补充端点   |
| GET  | `/fandoms/:id/world-settings` | 世界观列表，只读补充端点 |
| POST | `/fandoms/:id/imports`        | 上传 txt 并创建导入任务  |
| GET  | `/imports/:id`                | 导入任务详情             |
| GET  | `/imports/:id/chapters`       | 导入章节列表             |
| GET  | `/imports/:id/candidates`     | 候选列表                 |
| POST | `/candidates/:id/approve`     | 接受候选                 |
| POST | `/candidates/:id/reject`      | 拒绝候选                 |
| POST | `/novels`                     | 新建 Novel               |
| GET  | `/novels`                     | Novel 列表               |
| GET  | `/novels/:id`                 | Novel 详情               |
| POST | `/novels/:id/chapters`        | 新建章节                 |
| GET  | `/novels/:id/chapters`        | 章节列表                 |
| GET  | `/chapters/:id`               | 章节详情                 |
| PUT  | `/chapters/:id`               | 保存章节                 |
| POST | `/chapters/:id/generate`      | 触发 AI 生成             |
| POST | `/chapters/:id/complete`      | 完成本章                 |
| GET  | `/generation-tasks/:id`       | 查询任务                 |

> 注释：API 清单比设计文档多了两个只读实体列表端点，这是为了满足 MVP-0 前端“接受后实体表实时刷新”的页面需求。它们不改变 MVP-0 边界，因为不提供新增、编辑、删除实体能力。

---

## 12. DoD 验收

按以下顺序人工验证：

1. `docker compose up -d` 成功。
2. `pnpm dev` 后 API 和 Web 均可访问。
3. 打开 `http://localhost:5173`。
4. 创建 Fandom。
5. 上传 `specs/demo.txt`。
6. 等待导入完成，进入 `reviewing`。
7. 至少看到 5 个候选人物、5 个候选世界观。
8. 接受至少 3 个人物和 3 个世界观。
9. 创建 Novel。
10. 创建第 1 章。
11. 填写大纲、目标、出场人物。
12. 点击生成本章正文。
13. 180 秒内得到正文。
14. 点击完成本章。
15. 章节状态变为 `final`，并生成 summary。
16. 创建第 2 章并生成。
17. 第 2 章正文明确引用第 1 章事件。
18. 执行 `pnpm --filter api test:cov`，覆盖率 >= 40%。

> 注释：DoD 按真实用户路径排列，而不是按模块排列。这样验收时可以暴露跨模块衔接问题，例如候选审核后向量没写入、完结后摘要没回灌、第二章生成没有召回第一章等。

---

## 13. 明确不实现

MVP-0 不要顺手实现以下功能：

- 登录、注册、JWT。
- Repository 抽象层。
- Tauri 桌面端。
- 自动保存、快照、冲突处理。
- SSE 流式生成。
- Prompt 模板 registry 和版本管理。
- Token 预算裁剪。
- Map-reduce 长摘要。
- 向量一致性巡检。
- 用户设置页。
- Character / WorldSetting 手动 CRUD。
- 生产安全、备份、配额、审计。

这些功能进入 MVP-1 / MVP-2。

> 注释：这份“不实现”清单和实现步骤一样重要。MVP-0 最大风险不是代码写不出来，而是范围蔓延导致闭环迟迟跑不通。任何不直接服务“导入 -> 审核 -> 生成 -> 回灌”的功能都应推迟。

---

## 14. 推荐实现顺序

严格按以下顺序提交小步变更：

1. workspace、docker-compose、env。
2. NestJS health、PrismaService、demo user middleware。
3. Prisma schema、pgvector migration、seed。
4. Fandom CRUD。
5. Novel CRUD + 默认 volume/style。
6. Chapter CRUD。
7. LLM ping。
8. MinIO StorageService。
9. Import API。
10. Text cleaning + splitting 单测。
11. ImportWorker cleaning/splitting。
12. Prompt 文件。
13. ImportWorker summarizing/extracting。
14. EmbeddingWorker。
15. Candidate approve/reject。
16. RAG service。
17. PromptBuilderService。
18. GenerateWorker + generate API。
19. Complete chapter + summary embedding。
20. GenerationTask 查询。
21. Web API client 和布局。
22. Fandom 页面和导入审核。
23. Novel 页面。
24. Chapter editor。
25. smoke scripts。
26. 单测补齐。
27. 手工 DoD 验收并记录问题。

每完成 3-5 个步骤就运行：

```bash
pnpm --filter api build
pnpm --filter api test
pnpm --filter web build
```

命令解释：

- `pnpm --filter api build`：只编译后端，检查 NestJS / TypeScript 是否能成功构建。
- `pnpm --filter api test`：只运行后端测试，快速确认核心 service 没被改坏。
- `pnpm --filter web build`：只构建前端，检查 React / TypeScript / Vite 是否能成功打包。
- 为什么每 3-5 步就跑一次：越早发现问题越容易定位。等全部做完再跑，可能同时出现数据库、类型、接口、页面多个问题。
- 成功标志：三条命令都无 error 退出。

> 注释：推荐顺序按依赖链排列，尽量让每一步都有可运行的中间状态。频繁 build/test 可以尽早发现类型错误、migration 错误和前后端接口漂移，避免最后联调时同时面对太多问题。

---

## 15. 零基础逐步解释

这一节按“实际从 0 到 1 实现”的顺序解释每一步。每一步都回答四个问题：

- 你在做什么。
- 为什么要这么做。
- 这一步产出什么。
- 做完后如何判断没做错。

### 15.1 创建 pnpm workspace

执行 `corepack enable pnpm` 是为了让 Node.js 使用内置的 Corepack 管理 pnpm 版本。pnpm 是包管理器，负责下载依赖、执行脚本、管理多项目仓库。

执行 `pnpm init` 是为了在仓库根目录创建 `package.json`。`package.json` 可以理解为这个工程的“项目说明书”，里面记录项目名字、脚本命令和依赖。

创建 `pnpm-workspace.yaml` 是为了告诉 pnpm：这个仓库不是单个项目，而是一个 workspace，里面包含 `apps/*` 和 `packages/*`。`apps/api` 是后端应用，`apps/web` 是前端应用，`packages/shared` 是前后端共享代码。

为什么不把前后端放在同一个目录里：前端和后端运行方式不同、依赖不同、构建命令不同。分开放可以让职责清晰，也方便以后增加桌面端。

做完后应该看到：

```text
package.json
pnpm-workspace.yaml
```

判断是否正确：在根目录执行 `pnpm install` 不应报 workspace 配置错误。

### 15.2 创建根 package.json 脚本

根 `package.json` 里的 `dev`、`build`、`lint`、`test` 是总控命令。

`pnpm -r --parallel dev` 的意思是：递归找到 workspace 中所有包，并行执行它们各自的 `dev` 脚本。以后只需要在根目录执行 `pnpm dev`，前端和后端就能一起启动。

`pnpm -r build` 的意思是：递归执行所有包的 build。它能检查前端、后端、shared 包是否都能成功编译。

为什么先写这些脚本：项目越往后文件越多，如果每次都进入不同目录执行命令，会很容易漏掉某一端。根脚本把常用动作统一起来。

做完后应该看到：根 `package.json` 中有 `dev/build/lint/test/format`。

判断是否正确：即使子项目还没创建，根 `package.json` 本身必须是合法 JSON，不能有注释、尾逗号或重复字段。

### 15.3 创建 .gitignore

`.gitignore` 告诉 Git 哪些文件不要提交。

`node_modules` 是依赖下载目录，体积很大，而且可以通过 `pnpm install` 重新生成，所以不能提交。

`dist` 是构建产物，可以通过 `build` 重新生成，所以不能提交。

`.env` 保存本地密钥，比如 LLM API key，不能提交。

`coverage` 是测试覆盖率报告，可以重新生成，不需要提交。

为什么必须做：如果把 `node_modules` 或 `.env` 提交，会导致仓库变大、密钥泄漏、不同开发环境互相污染。

做完后判断：`git status` 不应该显示 `node_modules`、`.env`、`dist`。

### 15.4 创建 .env.example 和 .env

`.env.example` 是配置模板，告诉开发者需要哪些环境变量。

`.env` 是你本机真正使用的配置，里面可以填真实 API key。

`DATABASE_URL` 告诉 Prisma 连接哪个 PostgreSQL 数据库。

`REDIS_HOST` 和 `REDIS_PORT` 告诉 BullMQ 连接哪个 Redis。

`MINIO_*` 告诉后端如何连接对象存储。

`LLM_*` 告诉后端使用哪个模型、哪个 API 地址、哪个 key。

`WEB_ORIGIN` 用于 CORS，表示允许哪个前端地址访问 API。

为什么 `.env.example` 和 `.env` 要分开：模板可以提交给所有人，真实配置只留在本机。

做完后判断：根目录应该同时有 `.env.example` 和 `.env`，但 `git status` 不应该显示 `.env`。

### 15.5 创建 docker-compose.yml

`docker-compose.yml` 是本地依赖的一键启动说明。

`postgres` 服务提供主数据库。业务数据、导入任务、章节、候选实体、向量文档都存在 PostgreSQL。

`pgvector/pgvector:pg16` 是带 pgvector 扩展的 PostgreSQL 镜像。普通 PostgreSQL 不能直接存向量，pgvector 让数据库支持 embedding 检索。

`redis` 服务提供队列后端。BullMQ 需要 Redis 保存 job 状态，比如 pending、running、failed。

`minio` 服务模拟 S3 对象存储。上传的 txt 原文存在 MinIO，数据库只保存 object key。

`ports` 把容器端口映射到本机端口。例如 `5432:5432` 表示本机 `localhost:5432` 可以访问容器内 PostgreSQL。

`volumes` 保存容器数据。没有 volume，容器删除后数据库和 MinIO 文件就会丢。

为什么不直接安装 PostgreSQL、Redis、MinIO 到本机：Docker Compose 可以保证所有开发者使用一致版本，启动和清理都更简单。

做完后执行：

```bash
docker compose up -d
docker compose ps
```

判断是否正确：三个服务都应是 running；MinIO 控制台 `http://localhost:9001` 能打开。

### 15.6 创建 NestJS API

`pnpm dlx @nestjs/cli new apps/api` 会创建一个 NestJS 后端项目。

NestJS 是 Node.js 后端框架，提供 Controller、Service、Module 等结构。

Controller 负责接收 HTTP 请求，例如 `POST /fandoms`。

Service 负责业务逻辑，例如创建 fandom、投递导入任务。

Module 负责把相关 Controller 和 Service 组织在一起，例如 `FandomModule`。

为什么用 NestJS：它有清晰的模块边界，适合这个项目按业务模块拆分。后续加鉴权、队列、数据库、配置也都有成熟模式。

安装 `@nestjs/config` 是为了读取 `.env`。

安装 `@nestjs/swagger` 是为了生成 API 文档。

安装 `@prisma/client` 和 `prisma` 是为了访问数据库。

安装 `class-validator` 和 `class-transformer` 是为了校验请求参数。

安装 `bullmq` 和 `ioredis` 是为了处理后台队列。

安装 `minio` 是为了连接对象存储。

安装 `openai` 是为了调用 OpenAI 兼容 LLM 接口。

安装 `tsx` 是为了直接运行 TypeScript 脚本，比如 seed 和 llm ping。

做完后判断：`apps/api` 下应该有 `src/main.ts`、`src/app.module.ts`、`package.json`。

### 15.7 创建 Vite React Web

`pnpm create vite apps/web --template react-ts` 会创建前端项目。

Vite 是前端开发服务器和构建工具。它启动快，适合本地开发。

React 是前端 UI 框架，用组件组织页面。

TypeScript 让前端代码有类型检查，减少字段写错。

安装 `@tanstack/react-query` 是为了管理服务端数据，例如 fandom 列表、导入任务状态。

安装 `axios` 是为了发送 HTTP 请求。

安装 `react-router-dom` 是为了实现 `/fandoms/:id` 这类页面路由。

安装 `zustand` 是为了以后放少量本地状态。MVP-0 可以少用或不用。

安装 `lucide-react` 是为了按钮图标。

安装 Tailwind 和 shadcn/ui 是为了快速搭建一致的界面，不从零写所有 CSS。

为什么不用复杂富文本编辑器：MVP-0 的目标是验证 AI 生成闭环，textarea 已经足够写大纲和正文。

做完后判断：执行 `pnpm --filter web dev`，浏览器打开 `http://localhost:5173` 能看到 Vite 页面。

### 15.8 创建 shared 包

`packages/shared` 是前端和后端都能引用的共享包。

最先放进去的是枚举和类型，例如 `ImportStatus`、`CandidateType`、`ChapterStatus`。

为什么要共享类型：如果后端返回 `reviewing`，前端却写成 `review`，页面逻辑会失效。共享类型可以让这种错误在编译时暴露。

为什么暂时不放业务逻辑：共享包太容易膨胀。MVP-0 只共享稳定、简单、两端都需要的内容。

做完后判断：`packages/shared/src/index.ts` 存在，根目录 `pnpm install` 能识别这个 workspace 包。

### 15.9 初始化 Prisma

`pnpm prisma init` 会创建 `prisma/schema.prisma`。

`schema.prisma` 是数据库结构的代码化描述。你在里面定义 model，Prisma 根据 model 生成数据库 migration 和 TypeScript client。

比如 `Fandom` model 对应数据库中的 `fandoms` 表。

为什么用 Prisma：它能把数据库表映射成 TypeScript API，减少手写 SQL 的数量。

为什么仍然需要 raw SQL：pgvector 的 `vector(1536)` Prisma 不能完整管理，所以向量列和向量检索需要 raw SQL。

做完后判断：`apps/api/prisma/schema.prisma` 存在，里面 datasource 是 PostgreSQL。

### 15.10 定义 13 张表

`User` 表保存用户。MVP-0 只有 demo user，但表要提前建好。

`Fandom` 表保存原作知识库，例如某个动漫、小说或游戏。

`Novel` 表保存用户要写的同人小说项目。

`ImportTask` 表保存一次导入任务的状态，例如 processing、reviewing、failed。

`ImportedChapter` 表保存从 txt 原文切出来的原作章节。

`ExtractionCandidate` 表保存 AI 抽取出的候选人物、世界观、事件。

`Character` 表保存审核通过的人物卡。

`WorldSetting` 表保存审核通过的世界观设定。

`Volume` 表保存小说分卷。MVP-0 默认只有“正文卷”。

`Chapter` 表保存用户创作的同人章节。

`WritingStyle` 表保存写作风格。MVP-0 只建默认风格。

`VectorDocument` 表保存所有可被 RAG 检索的文本及 embedding。

`GenerationTask` 表保存每次 LLM 调用任务，例如章节生成、摘要生成。

为什么这些表都要在 MVP-0 建：导入、审核、生成、回灌这条闭环会用到它们。少任何一类，闭环都会断。

做完后判断：执行 migration 后数据库里能看到这些表。

### 15.11 给表增加 created_at、updated_at、deleted_at

`created_at` 记录数据创建时间。

`updated_at` 记录数据最后更新时间。

`deleted_at` 用于软删除。软删除的意思是不真的删除数据，只标记删除时间。

为什么 MVP-0 不用软删除还要建 `deleted_at`：后续版本需要删除、恢复、审计。如果现在不建，以后每张表都要补 migration。

做完后判断：每张业务表都有这三个时间列。

### 15.12 创建 pgvector migration

`CREATE EXTENSION IF NOT EXISTS vector;` 是启用 pgvector 扩展。

ivfflat 索引用于加速向量相似度查询。

`vector_cosine_ops` 表示使用 cosine 距离，适合文本 embedding 相似度。

`vector_documents_scope_idx` 是普通索引，用于先按 user、fandom、novel、sourceType 缩小范围，再做向量排序。

为什么需要索引：没有索引时，数据库可能扫描所有向量。数据少时还行，数据多了检索会变慢。

做完后判断：migration 成功执行，`vector_documents` 表有 embedding 索引。

### 15.13 创建 seed.ts

seed 是数据库初始化脚本。

MVP-0 没有注册登录，所以需要提前插入一个固定 demo user。

`upsert` 的意思是：如果已存在就不动，如果不存在就创建。这样 seed 可以重复执行。

为什么不用应用启动时自动创建：启动应用和初始化数据库是两件事，分开后更容易排查问题。

做完后判断：执行 `pnpm --filter api seed` 后，`users` 表里有 demo user。

### 15.14 创建 demo user middleware

middleware 是请求进入 Controller 前会先经过的函数。

`DemoUserMiddleware` 给每个请求都加上 `req.userId = DEMO_USER_ID`。

后续 Controller 可以从 `req.userId` 知道当前用户是谁。

为什么不直接在 Service 里写死 demo user：把 userId 从请求传入 Service，可以模拟真实登录后的形态。MVP-1 替换鉴权时，Service 基本不用改。

做完后判断：任意 Controller 中打印 `req.userId`，值都是 demo uuid。

### 15.15 创建统一错误处理

统一错误处理负责把各种错误变成同一种 JSON 格式。

例如参数错误返回：

```json
{
  "code": "VALIDATION_FAILED",
  "message": "xxx",
  "details": {}
}
```

为什么要统一：前端只需要写一种错误展示逻辑。如果每个接口错误格式不同，前端会变复杂。

常见错误码：

- `NOT_FOUND` 表示资源不存在。
- `VALIDATION_FAILED` 表示请求参数错。
- `CONFLICT` 表示唯一约束冲突。
- `LLM_PROVIDER_ERROR` 表示模型服务失败。
- `IMPORT_PARSE_FAILED` 表示导入文本无法切章。

做完后判断：请求一个不存在的资源，返回 JSON 中有 `code` 和 `message`。

### 15.16 创建 PrismaService

`PrismaService` 是后端访问数据库的入口。

它继承 `PrismaClient`，启动时连接数据库，关闭时断开连接。

为什么不在每个 Service 里 new PrismaClient：每个地方都 new 会创建太多连接，也难以统一管理生命周期。

为什么查询要带 `userId` 和 `deletedAt: null`：这是 MVP-1 多用户和软删除的提前约束。

做完后判断：在任意业务 Service 中可以注入 `PrismaService` 并查询数据库。

### 15.17 创建 QueueModule

QueueModule 创建三个队列：

- import queue 处理导入。
- embedding queue 处理向量化。
- generate queue 处理章节生成和完结摘要。

为什么拆三个队列：不同任务耗时和失败原因不同。拆开后排查更清楚，也便于后续分别设置并发数。

为什么要 Bull Board：本地开发时可以看到 job 是否卡住、失败、重试。

做完后判断：访问 `/admin/queues` 能看到队列页面。

### 15.18 创建 HealthController

`GET /health` 返回 `{ ok: true }`。

它是最小健康检查接口。

为什么需要：启动后先打 `/health`，可以确认 API 进程和路由正常，再继续查数据库或业务问题。

做完后判断：`curl http://localhost:3000/health` 返回 ok。

### 15.19 实现 Fandom 模块

Fandom 是原作知识库。

`CreateFandomDto` 描述创建知识库需要哪些字段。

`FandomController` 定义 HTTP 路由。

`FandomService` 执行业务逻辑和数据库操作。

`POST /fandoms` 创建知识库。

`GET /fandoms` 获取当前用户的知识库列表。

`GET /fandoms/:id` 获取单个知识库详情。

为什么先做 Fandom：后续导入原作、审核实体、创建同人小说都要关联 fandom。

做完后判断：用 curl 创建 fandom 后，数据库 `fandoms` 表出现一行。

### 15.20 实现 Novel 模块

Novel 是用户创作的小说项目。

创建 Novel 时必须关联 Fandom，因为同人小说生成时要从对应原作知识库检索设定。

事务里同时创建 Volume 和 WritingStyle。

为什么用事务：如果 novel 创建成功但 volume 创建失败，系统会出现半成品数据。事务可以保证要么全成功，要么全失败。

为什么默认创建“正文卷”：章节必须属于某个 volume。MVP-0 不让用户管理分卷，所以给一个默认卷。

为什么默认创建“默认风格”：PromptBuilder 需要写作风格输入。即使为空，也要有一条记录，避免生成时到处判断 null。

做完后判断：创建 novel 后，数据库里同时出现 novel、volume、writing_style。

### 15.21 实现 Chapter CRUD

Chapter 是用户正在写的同人章节。

创建章节时自动计算 `chapterNo`，避免前端自己判断下一章编号。

`PUT /chapters/:id` 保存章节内容、大纲、目标、出场人物等。

为什么 PUT 全量更新：MVP-0 不做自动保存和冲突处理，全量保存最简单。

为什么增加 `goal`、`extra_notes`、`appearing_character_ids`：这些字段直接进入生成 Prompt，让模型知道本章要写什么、有哪些人物。

做完后判断：创建 novel 后可以创建第 1 章，再 PUT 保存大纲和正文。

### 15.22 实现 LlmService

`complete` 用于文本生成，例如摘要、抽取、章节正文。

`embed` 用于生成文本向量，例如人物卡向量、章节摘要向量。

为什么同一个 Service 管这两个方法：它们都依赖同一个 LLM Provider 配置，包括 API key、base URL 和 model。

为什么要写 `llm:ping`：在业务代码接入前，先确认 API key、网络、模型名可用。否则后面导入失败时很难判断是业务问题还是模型配置问题。

做完后判断：`pnpm --filter api llm:ping` 能得到模型回复。

### 15.23 创建 Prompt 文件

Prompt 是发给模型的指令。

`summarize.txt` 告诉模型如何总结原作章节。

`extract.txt` 告诉模型如何抽取人物、世界观、事件，并要求输出 JSON。

`generate.txt` 告诉模型如何根据小说信息、风格、章节大纲、RAG 内容写正文。

为什么 Prompt 放在文件里：Prompt 是产品核心资产，应该能被 review、diff、版本管理。

为什么抽取要求只输出 JSON：后端需要解析模型输出。如果模型输出 Markdown 或解释文字，JSON 解析会失败。

做完后判断：后端启动时能读取三个 Prompt 文件。

### 15.24 实现 StorageService

StorageService 封装 MinIO 操作。

`putObject` 上传文件。

`getObject` 下载文件。

`ensureBucket` 确保 bucket 存在。

为什么封装：业务代码不应该到处直接调用 MinIO SDK。以后换 S3，只需要改 StorageService。

为什么 objectName 带 userId、fandomId、importTaskId：这样文件路径可追踪，不同用户和任务不会混在一起。

做完后判断：上传 txt 后，MinIO bucket 中能看到对应 object。

### 15.25 实现 Import API

`POST /fandoms/:id/imports` 接收上传文件。

它做四件事：

1. 校验文件。
2. 创建 import task。
3. 上传原文到 MinIO。
4. 投递后台任务。

为什么不在接口里直接处理全文：切章、摘要、抽取都很慢。HTTP 请求长时间不返回会超时，用户也看不到进度。

为什么要记录 `object_key`：worker 后续需要知道从 MinIO 哪里把原文读回来。

做完后判断：上传后立即返回 import task，数据库里有 pending 任务，队列里有 job。

### 15.26 实现文本清洗

文本清洗把不同来源的 txt 变成统一格式。

去 BOM 是为了避免第一行标题前出现隐藏字符，导致标题匹配失败。

统一换行是为了让 Windows、macOS、Linux 文本都能按同一种规则处理。

压缩空行是为了减少无意义内容影响切章。

替换全角空格是为了让标题和正文判断更稳定。

为什么先清洗再切章：切章依赖行首、空行、短行等规则，脏文本会导致规则失效。

做完后判断：单测输入混乱换行和 BOM，输出应干净稳定。

### 15.27 实现章节切分

章节切分把一整本原作 txt 切成多个 `ImportedChapter`。

优先匹配 `第 N 章`，因为中文小说最常见。

再匹配 `Chapter N`，兼容英文或混合格式。

再匹配 Markdown `# 标题`，兼容 md 文本。

再匹配短行标题，兼容没有章节编号但有独立标题的文本。

最后滑窗切分，保证没有标题的文本也能处理。

为什么滑窗约 6000 字：摘要和抽取需要控制单次 LLM 输入长度。太长容易超过上下文，太短会丢失章节语义。

做完后判断：`specs/demo.txt` 能切出多个章节，每章有 chapterNo、title、content、wordCount。

### 15.28 实现 ImportWorker

ImportWorker 是导入流水线的后台执行者。

`cleaning` 阶段清洗文本。

`splitting` 阶段切章并写入 `imported_chapters`。

`summarizing` 阶段逐章调用 LLM 生成摘要。

`extracting` 阶段逐章调用 LLM 抽取候选实体。

`embedding` 阶段把摘要向量化，写入 `vector_documents`。

为什么每个阶段都更新 `stage` 和 `progress`：前端可以显示“正在切章”“正在摘要”，用户知道系统没有卡死。

为什么 MVP-0 串行处理：并发会带来限流、重试、顺序、部分失败等复杂问题。先串行跑通闭环更重要。

为什么失败时标记整个 import task failed：MVP-0 不做章节级重试，整体失败最简单，也容易排查。

做完后判断：上传 txt 后，任务状态从 pending 到 processing，再到 reviewing。

### 15.29 实现 EmbeddingWorker

EmbeddingWorker 把文本转成向量。

输入是 chunkText，例如章节摘要或人物描述。

输出是 1536 维数字数组。

这些数字写入 `vector_documents.embedding`。

为什么要向量化：RAG 检索需要比较“查询文本”和“知识文本”的语义相似度。普通关键词匹配无法可靠找出相关设定。

为什么所有来源都写入同一张 `vector_documents`：RAG 查询时可以统一按 sourceType 检索人物、世界观、原作摘要、前文摘要。

做完后判断：`vector_documents` 中有 sourceType 为 `IMPORTED_CHAPTER_SUMMARY` 的记录，embedding 不为空。

### 15.30 实现候选审核

AI 抽取出来的是 candidate，不直接进入正式表。

用户点击接受后，candidate 才变成 Character 或 WorldSetting。

用户点击拒绝后，candidate 标记为 rejected。

为什么需要人工审核：LLM 可能抽错、编造或重复。未经审核直接进入 RAG，会污染后续生成。

为什么同名冲突返回 409：MVP-0 不做合并 UI。如果已经有同名实体，最安全的做法是阻止重复创建，让用户拒绝候选。

为什么 EVENT 不建正式表：MVP-0 设计没有事件正式表，事件候选只用于观察抽取质量，不参与核心生成。

做完后判断：接受人物后，`characters` 表新增记录，且 `vector_documents` 新增 `CHARACTER` 向量。

### 15.31 实现 RAG Service

RAG Service 负责为章节生成找上下文。

它先把当前章节标题、大纲、目标、出场人物拼成 query。

然后把 query 转成 embedding。

再分别检索：

- 相关人物。
- 相关世界观。
- 相关原作摘要。
- 相关前文摘要。

为什么分四路检索：不同来源有不同用途。人物保证不 OOC，世界观保证设定不冲突，原作摘要保证符合原作，前文摘要保证连续剧情。

为什么还要直接取最近 3 章：向量检索可能漏掉最近发生但语义不明显的事件。最近章节直拉可以保护时间连续性。

做完后判断：给第 2 章构造 query 时，RAG 结果能返回第 1 章 summary。

### 15.32 实现 PromptBuilderService

PromptBuilderService 把 Novel、WritingStyle、Chapter、RAG 结果拼成最终 Prompt。

它不是调用模型的地方，只负责组织文本。

为什么要独立：Prompt 拼装规则会频繁调整，独立后可以单测，不需要真的调用 LLM。

为什么空字段整段省略：如果 Prompt 里出现“分歧点：空”，模型可能误解为空设定。省略更自然。

为什么要截断字段：MVP-0 不做精确 token 预算，但至少要限制用户输入和 RAG 文本长度，降低超上下文风险。

做完后判断：单测中空字段不会出现在最终 Prompt，超长字段会被截断。

### 15.33 实现章节生成接口

`POST /chapters/:id/generate` 不直接生成正文，而是创建 task 并投递队列。

接口立即返回 `{ taskId }`。

前端拿 taskId 去轮询 `GET /generation-tasks/:id`。

为什么这样设计：章节生成可能很慢，HTTP 请求不能一直等。task 机制可以保存状态、错误、token 用量和结果。

做完后判断：点击生成后，`generation_tasks` 表出现 `GENERATE_CHAPTER` 任务。

### 15.34 实现 GenerateWorker

GenerateWorker 真正执行章节生成。

它先把 task 改成 running。

然后读取 chapter、novel、writingStyle。

然后调用 RAG 找上下文。

然后调用 PromptBuilder 拼 Prompt。

然后调用 LLM 生成正文。

最后把正文写回 `chapters.content`，并把 task 改成 success。

为什么失败时不覆盖正文：如果用户已有草稿，失败调用不能破坏用户内容。

为什么成功后直接覆盖正文：MVP-0 不做候选稿管理，直接覆盖能最快完成闭环。

做完后判断：task success 后，chapter 的 content 有正文，status 变为 generated。

### 15.35 实现 GenerationTask 查询

`GET /generation-tasks/:id` 返回任务状态。

前端用它判断：

- 是否还在 pending。
- 是否 running。
- 是否 success。
- 是否 failed。
- 失败原因是什么。

为什么不直接轮询 chapter：chapter 只能看到最终正文，看不到 LLM 错误、token 用量和 task 状态。

做完后判断：生成过程中轮询 task，状态会从 pending/running 变为 success 或 failed。

### 15.36 实现完结章节

`POST /chapters/:id/complete` 表示用户确认本章完成。

完成后系统生成本章摘要。

摘要写入 `chapters.summary`。

摘要再向量化写入 `vector_documents`，sourceType 为 `CHAPTER_SUMMARY`。

最后 chapter 状态变为 final。

为什么完结才回灌：草稿可能频繁变化，不适合作为后续 RAG 的稳定事实。final 表示用户认可，可以影响后续章节。

为什么摘要回灌而不是全文回灌：全文太长，检索和 Prompt 成本高。摘要更适合作为长期上下文。

做完后判断：完成第 1 章后，数据库有 `CHAPTER_SUMMARY` 向量，第 2 章生成能召回它。

### 15.37 创建前端 API client

`api/client.ts` 创建 axios 实例。

`baseURL` 指向后端地址。

为什么统一 axios 实例：以后加错误处理、请求日志、认证 header 时只改一个地方。

做完后判断：前端任意 API 文件都从 `api` 实例发送请求。

### 15.38 创建前端 hooks

每个 hook 对应一个后端 API 或一组相关 API。

例如 `useFandoms()` 获取知识库列表。

`useCreateFandom()` 创建知识库。

`useImportTask()` 轮询导入任务。

`useGenerationTask()` 轮询生成任务。

为什么用 hooks：页面组件只关心“加载中、数据、错误、点击动作”，不直接写 axios 细节。

为什么轮询间隔 2 秒：本地体验足够及时，也不会给后端造成太多压力。

做完后判断：页面组件中没有散落大量 axios 调用，API 逻辑集中在 `src/api`。

### 15.39 创建前端布局

布局包含顶栏、侧边导航和主内容区域。

顶栏显示产品名和 Demo User。

侧边导航连接工作台、知识库、我的小说。

为什么需要统一布局：用户在不同页面之间切换时不会迷路，页面也不用重复写导航。

做完后判断：访问任意路由都能看到同一套导航。

### 15.40 实现工作台

工作台是入口页。

它展示新建知识库、新建小说、最近列表。

为什么不做复杂统计：MVP-0 的核心不是运营分析，而是让用户尽快进入导入和写作流程。

做完后判断：打开 `/` 可以进入 fandom 和 novel 相关页面。

### 15.41 实现知识库列表

`/fandoms` 展示所有知识库。

新建对话框提交 `POST /fandoms`。

创建成功后跳转详情页。

为什么创建后跳详情：用户下一步通常就是上传原作，所以直接进入详情最短。

做完后判断：新建 fandom 后列表刷新，并跳到 `/fandoms/:id`。

### 15.42 实现 Fandom 详情

Fandom 详情页承载四件事：

1. 上传 txt。
2. 查看导入进度。
3. 审核候选实体。
4. 查看已入库人物和世界观。

为什么放在一个页面：MVP-0 页面越少，状态传递越简单。导入和审核本来也是同一条流程。

为什么 EVENT 接受按钮可以隐藏：MVP-0 没有正式事件表，接受事件不会进入后续 RAG 核心链路。

做完后判断：上传后能看到进度，reviewing 后能看到候选，接受后实体列表刷新。

### 15.43 实现小说列表

`/novels` 展示用户的小说项目。

新建小说需要选择 fandom。

为什么必须选 fandom：同人生成依赖原作知识库。如果 novel 没有关联 fandom，RAG 找不到原作设定。

做完后判断：创建 novel 后跳转 `/novels/:id`。

### 15.44 实现小说空间

小说空间展示小说基本信息和章节列表。

新建章节按钮调用 `POST /novels/:id/chapters`。

为什么章节列表在小说空间：用户写作时需要知道已有多少章、每章状态是什么。

做完后判断：点击新建章节后列表出现第 1 章，点击章节进入编辑器。

### 15.45 实现章节编辑器

章节编辑器是 MVP-0 最核心前端页面。

标题、大纲、目标、额外要求是给模型的写作指令。

出场人物多选告诉模型本章哪些人物应该出现。

正文 textarea 展示和编辑生成结果。

保存按钮调用 `PUT /chapters/:id`。

生成按钮先保存表单，再调用 generate。

完成按钮先保存正文，再调用 complete。

为什么生成前先保存：worker 从数据库读取章节信息。如果不先保存，模型可能拿到旧大纲。

为什么完成前先保存：摘要应该基于用户最终确认的正文，而不是旧正文。

做完后判断：编辑、保存、生成、完成都能独立成功，刷新页面后内容还在。

### 15.46 编写单元测试

单元测试验证单个函数或 service 的行为。

文本清洗和切章必须测，因为它们决定知识库质量。

PromptBuilder 必须测，因为 Prompt 错了模型输出会偏。

RAG 必须测，因为过滤条件错了可能召回不到内容，甚至未来多用户时召回别人数据。

Extraction 必须测，因为审核会写正式实体和向量。

Chapter 必须测，因为章节编号和保存是写作基础。

为什么不是所有代码都测：MVP-0 时间有限，优先测风险最高、最影响闭环的模块。

做完后判断：`pnpm --filter api test:cov` 覆盖率 >= 40%。

### 15.47 编写 smoke-import 脚本

smoke-import 脚本模拟用户导入原作。

它会创建 fandom、上传 demo.txt、轮询导入任务、列候选、接受部分候选。

为什么需要脚本：手点页面容易漏步骤，脚本可以重复跑，适合回归验证。

做完后判断：脚本结束后，import task 为 reviewing 或 completed，候选数量足够，向量表有数据。

### 15.48 编写 smoke-generation 脚本

smoke-generation 脚本模拟用户写小说。

它会创建 novel、创建第 1 章、生成、完结、再生成第 2 章。

为什么第 2 章是关键：只有第 2 章能验证第 1 章摘要是否成功回灌进 RAG。

做完后判断：第 2 章正文能提到第 1 章发生的事件。

### 15.49 执行首次启动

首次启动顺序是：

1. 安装依赖。
2. 复制 `.env`。
3. 启动 Docker 依赖。
4. 生成 Prisma client。
5. 执行 migration。
6. 执行 seed。
7. 启动前后端。

为什么顺序不能乱：应用启动需要数据库存在，数据库表需要 migration 创建，demo user 需要 seed 插入。

做完后判断：

- Web 能打开。
- `/health` 返回 ok。
- Bull Board 能打开。
- MinIO Console 能打开。

### 15.50 最终 DoD 为什么这样验收

DoD 不按“模块完成”验收，而按真实用户路径验收。

创建 Fandom 验证基础 CRUD。

上传 txt 验证 MinIO、Import API、Queue。

等待 reviewing 验证 worker、LLM 摘要、抽取、embedding。

接受候选验证审核和实体向量化。

创建 Novel 和 Chapter 验证写作数据模型。

生成第 1 章验证 RAG、PromptBuilder、GenerateWorker、LLM。

完成第 1 章验证摘要回灌。

生成第 2 章验证前文摘要能被召回。

测试覆盖率验证核心逻辑不是只能手工跑通。

这套验收能证明 MVP-0 的目标已经达成：原作知识库、AI 生成、用户章节回灌形成闭环。

文档结束。
