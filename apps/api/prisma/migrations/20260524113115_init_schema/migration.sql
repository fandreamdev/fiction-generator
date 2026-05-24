CREATE EXTENSION IF NOT EXISTS vector;

-- CreateEnum
CREATE TYPE "chapter_status" AS ENUM ('draft', 'generated', 'final');

-- CreateEnum
CREATE TYPE "character_source_type" AS ENUM ('manual', 'imported', 'ai');

-- CreateEnum
CREATE TYPE "extraction_candidate_entity_type" AS ENUM ('CHARACTER', 'WORLD_SETTING', 'EVENT');

-- CreateEnum
CREATE TYPE "extraction_candidate_status" AS ENUM ('pending', 'approved', 'rejected');

-- CreateEnum
CREATE TYPE "fandom_type" AS ENUM ('novel', 'anime', 'game', 'film', 'other');

-- CreateEnum
CREATE TYPE "generation_task_type" AS ENUM ('IMPORT', 'SUMMARY', 'EXTRACT', 'GENERATE_CHAPTER', 'GENERATE_CHAPTER_SUMMARY', 'EMBEDDING');

-- CreateEnum
CREATE TYPE "generation_task_status" AS ENUM ('pending', 'running', 'success', 'failed');

-- CreateEnum
CREATE TYPE "import_task_source_type" AS ENUM ('txt', 'markdown', 'paste');

-- CreateEnum
CREATE TYPE "import_task_status" AS ENUM ('pending', 'processing', 'reviewing', 'completed', 'failed');

-- CreateEnum
CREATE TYPE "imported_chapter_status" AS ENUM ('pending', 'summarized', 'failed');

-- CreateEnum
CREATE TYPE "novel_type" AS ENUM ('fanfic', 'original');

-- CreateEnum
CREATE TYPE "novel_fanfic_type" AS ENUM ('canon', 'if', 'rebirth', 'transmigration', 'modern_au', 'au', 'sequel');

-- CreateEnum
CREATE TYPE "novel_status" AS ENUM ('draft', 'writing', 'finished');

-- CreateEnum
CREATE TYPE "vector_document_source_type" AS ENUM ('IMPORTED_CHAPTER_SUMMARY', 'CHARACTER', 'WORLD_SETTING', 'CHAPTER_SUMMARY', 'WRITING_STYLE');

-- CreateEnum
CREATE TYPE "world_setting_category" AS ENUM ('location', 'organization', 'power_system', 'item', 'rule', 'history', 'other');

-- CreateEnum
CREATE TYPE "world_setting_source_type" AS ENUM ('manual', 'imported', 'ai');

-- CreateTable
CREATE TABLE "chapters" (
    "id" BIGSERIAL NOT NULL,
    "novel_id" BIGINT NOT NULL,
    "volume_id" BIGINT NOT NULL,
    "chapter_no" INTEGER NOT NULL,
    "title" VARCHAR(256) NOT NULL,
    "outline" TEXT,
    "content" TEXT,
    "summary" TEXT,
    "word_count" INTEGER NOT NULL DEFAULT 0,
    "status" "chapter_status" NOT NULL,
    "deleted_flag" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "chapters_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "characters" (
    "id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "fandom_id" BIGINT NOT NULL,
    "novel_id" BIGINT,
    "name" VARCHAR(128) NOT NULL,
    "aliases" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "role" VARCHAR(32),
    "identity" TEXT,
    "appearance" TEXT,
    "personality" TEXT,
    "abilities" TEXT,
    "background" TEXT,
    "speaking_style" TEXT,
    "notes" TEXT,
    "source_type" "character_source_type" NOT NULL,
    "deleted_flag" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "characters_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "extraction_candidates" (
    "id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "fandom_id" BIGINT NOT NULL,
    "import_task_id" BIGINT NOT NULL,
    "source_chapter_id" BIGINT NOT NULL,
    "entity_type" "extraction_candidate_entity_type" NOT NULL,
    "name" VARCHAR(128) NOT NULL,
    "content_json" JSONB NOT NULL,
    "confidence" DECIMAL(3,2),
    "status" "extraction_candidate_status" NOT NULL,
    "target_entity_id" BIGINT,
    "deleted_flag" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "extraction_candidates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "fandoms" (
    "id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "name" VARCHAR(128) NOT NULL,
    "type" "fandom_type" NOT NULL,
    "description" TEXT,
    "notes" TEXT,
    "deleted_flag" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "fandoms_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "generation_tasks" (
    "id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "novel_id" BIGINT,
    "chapter_id" BIGINT,
    "task_type" "generation_task_type" NOT NULL,
    "status" "generation_task_status" NOT NULL,
    "model_name" VARCHAR(64),
    "prompt_text" TEXT,
    "result_text" TEXT,
    "token_usage" JSONB,
    "error_message" TEXT,
    "deleted_flag" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "generation_tasks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "import_tasks" (
    "id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "fandom_id" BIGINT NOT NULL,
    "file_name" VARCHAR(256),
    "source_type" "import_task_source_type" NOT NULL,
    "status" "import_task_status" NOT NULL,
    "progress" SMALLINT NOT NULL DEFAULT 0,
    "stage" VARCHAR(32),
    "error_message" TEXT,
    "deleted_flag" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "import_tasks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "imported_chapters" (
    "id" BIGSERIAL NOT NULL,
    "import_task_id" BIGINT NOT NULL,
    "fandom_id" BIGINT NOT NULL,
    "chapter_no" INTEGER NOT NULL,
    "title" VARCHAR(256),
    "content" TEXT,
    "summary" TEXT,
    "word_count" INTEGER,
    "status" "imported_chapter_status" NOT NULL,
    "deleted_flag" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "imported_chapters_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "novels" (
    "id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "fandom_id" BIGINT,
    "title" VARCHAR(128) NOT NULL,
    "type" "novel_type" NOT NULL,
    "fanfic_type" "novel_fanfic_type",
    "description" TEXT,
    "divergence_point" TEXT,
    "tone" VARCHAR(64),
    "status" "novel_status" NOT NULL,
    "deleted_flag" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "novels_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "users" (
    "id" BIGSERIAL NOT NULL,
    "email" VARCHAR(128) NOT NULL,
    "password_hash" VARCHAR(255) NOT NULL,
    "nickname" VARCHAR(64) NOT NULL DEFAULT '小说家',
    "deleted_flag" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vector_documents" (
    "id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "fandom_id" BIGINT,
    "novel_id" BIGINT,
    "source_type" "vector_document_source_type" NOT NULL,
    "source_id" BIGINT NOT NULL,
    "chunk_text" TEXT NOT NULL,
    "embedding" vector(1536),
    "metadata" JSONB,
    "deleted_flag" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "vector_documents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "volumes" (
    "id" BIGSERIAL NOT NULL,
    "novel_id" BIGINT NOT NULL,
    "title" VARCHAR(128) NOT NULL,
    "order_index" INTEGER NOT NULL,
    "summary" TEXT,
    "deleted_flag" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "volumes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "world_settings" (
    "id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "fandom_id" BIGINT NOT NULL,
    "novel_id" BIGINT,
    "category" "world_setting_category" NOT NULL,
    "name" VARCHAR(128) NOT NULL,
    "description" TEXT,
    "rules" TEXT,
    "notes" TEXT,
    "source_type" "world_setting_source_type" NOT NULL,
    "deleted_flag" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "world_settings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "writing_styles" (
    "id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "novel_id" BIGINT NOT NULL,
    "name" VARCHAR(128) NOT NULL,
    "description" TEXT,
    "tone" VARCHAR(128),
    "pacing" VARCHAR(128),
    "dialogue_style" TEXT,
    "description_style" TEXT,
    "avoid_rules" TEXT,
    "deleted_flag" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "writing_styles_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "chapters_novel_id_idx" ON "chapters"("novel_id");

-- CreateIndex
CREATE INDEX "chapters_volume_id_idx" ON "chapters"("volume_id");

-- CreateIndex
CREATE UNIQUE INDEX "chapters_novel_id_chapter_no_key" ON "chapters"("novel_id", "chapter_no");

-- CreateIndex
CREATE INDEX "characters_user_id_idx" ON "characters"("user_id");

-- CreateIndex
CREATE INDEX "characters_fandom_id_idx" ON "characters"("fandom_id");

-- CreateIndex
CREATE INDEX "characters_novel_id_idx" ON "characters"("novel_id");

-- CreateIndex
CREATE INDEX "characters_fandom_id_novel_id_name_idx" ON "characters"("fandom_id", "novel_id", "name");

-- CreateIndex
CREATE INDEX "extraction_candidates_user_id_idx" ON "extraction_candidates"("user_id");

-- CreateIndex
CREATE INDEX "extraction_candidates_fandom_id_idx" ON "extraction_candidates"("fandom_id");

-- CreateIndex
CREATE INDEX "extraction_candidates_import_task_id_idx" ON "extraction_candidates"("import_task_id");

-- CreateIndex
CREATE INDEX "extraction_candidates_source_chapter_id_idx" ON "extraction_candidates"("source_chapter_id");

-- CreateIndex
CREATE INDEX "extraction_candidates_fandom_id_entity_type_status_idx" ON "extraction_candidates"("fandom_id", "entity_type", "status");

-- CreateIndex
CREATE INDEX "fandoms_user_id_idx" ON "fandoms"("user_id");

-- CreateIndex
CREATE INDEX "generation_tasks_user_id_idx" ON "generation_tasks"("user_id");

-- CreateIndex
CREATE INDEX "generation_tasks_novel_id_idx" ON "generation_tasks"("novel_id");

-- CreateIndex
CREATE INDEX "generation_tasks_chapter_id_idx" ON "generation_tasks"("chapter_id");

-- CreateIndex
CREATE INDEX "import_tasks_user_id_idx" ON "import_tasks"("user_id");

-- CreateIndex
CREATE INDEX "import_tasks_fandom_id_idx" ON "import_tasks"("fandom_id");

-- CreateIndex
CREATE INDEX "imported_chapters_import_task_id_idx" ON "imported_chapters"("import_task_id");

-- CreateIndex
CREATE INDEX "imported_chapters_fandom_id_idx" ON "imported_chapters"("fandom_id");

-- CreateIndex
CREATE UNIQUE INDEX "imported_chapters_import_task_id_chapter_no_key" ON "imported_chapters"("import_task_id", "chapter_no");

-- CreateIndex
CREATE INDEX "novels_user_id_idx" ON "novels"("user_id");

-- CreateIndex
CREATE INDEX "novels_fandom_id_idx" ON "novels"("fandom_id");

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE INDEX "vector_documents_user_id_idx" ON "vector_documents"("user_id");

-- CreateIndex
CREATE INDEX "vector_documents_fandom_id_idx" ON "vector_documents"("fandom_id");

-- CreateIndex
CREATE INDEX "vector_documents_novel_id_idx" ON "vector_documents"("novel_id");

-- CreateIndex
CREATE INDEX "vector_documents_user_id_fandom_id_source_type_idx" ON "vector_documents"("user_id", "fandom_id", "source_type");

-- CreateIndex
CREATE INDEX "volumes_novel_id_idx" ON "volumes"("novel_id");

-- CreateIndex
CREATE UNIQUE INDEX "volumes_novel_id_order_index_key" ON "volumes"("novel_id", "order_index");

-- CreateIndex
CREATE INDEX "world_settings_user_id_idx" ON "world_settings"("user_id");

-- CreateIndex
CREATE INDEX "world_settings_fandom_id_idx" ON "world_settings"("fandom_id");

-- CreateIndex
CREATE INDEX "world_settings_novel_id_idx" ON "world_settings"("novel_id");

-- CreateIndex
CREATE INDEX "writing_styles_user_id_idx" ON "writing_styles"("user_id");

-- CreateIndex
CREATE INDEX "writing_styles_novel_id_idx" ON "writing_styles"("novel_id");

-- AddForeignKey
ALTER TABLE "chapters" ADD CONSTRAINT "chapters_novel_id_fkey" FOREIGN KEY ("novel_id") REFERENCES "novels"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "chapters" ADD CONSTRAINT "chapters_volume_id_fkey" FOREIGN KEY ("volume_id") REFERENCES "volumes"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "characters" ADD CONSTRAINT "characters_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "characters" ADD CONSTRAINT "characters_fandom_id_fkey" FOREIGN KEY ("fandom_id") REFERENCES "fandoms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "characters" ADD CONSTRAINT "characters_novel_id_fkey" FOREIGN KEY ("novel_id") REFERENCES "novels"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "extraction_candidates" ADD CONSTRAINT "extraction_candidates_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "extraction_candidates" ADD CONSTRAINT "extraction_candidates_fandom_id_fkey" FOREIGN KEY ("fandom_id") REFERENCES "fandoms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "extraction_candidates" ADD CONSTRAINT "extraction_candidates_import_task_id_fkey" FOREIGN KEY ("import_task_id") REFERENCES "import_tasks"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "extraction_candidates" ADD CONSTRAINT "extraction_candidates_source_chapter_id_fkey" FOREIGN KEY ("source_chapter_id") REFERENCES "imported_chapters"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "fandoms" ADD CONSTRAINT "fandoms_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "generation_tasks" ADD CONSTRAINT "generation_tasks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "generation_tasks" ADD CONSTRAINT "generation_tasks_novel_id_fkey" FOREIGN KEY ("novel_id") REFERENCES "novels"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "generation_tasks" ADD CONSTRAINT "generation_tasks_chapter_id_fkey" FOREIGN KEY ("chapter_id") REFERENCES "chapters"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "import_tasks" ADD CONSTRAINT "import_tasks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "import_tasks" ADD CONSTRAINT "import_tasks_fandom_id_fkey" FOREIGN KEY ("fandom_id") REFERENCES "fandoms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "imported_chapters" ADD CONSTRAINT "imported_chapters_import_task_id_fkey" FOREIGN KEY ("import_task_id") REFERENCES "import_tasks"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "imported_chapters" ADD CONSTRAINT "imported_chapters_fandom_id_fkey" FOREIGN KEY ("fandom_id") REFERENCES "fandoms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "novels" ADD CONSTRAINT "novels_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "novels" ADD CONSTRAINT "novels_fandom_id_fkey" FOREIGN KEY ("fandom_id") REFERENCES "fandoms"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vector_documents" ADD CONSTRAINT "vector_documents_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vector_documents" ADD CONSTRAINT "vector_documents_fandom_id_fkey" FOREIGN KEY ("fandom_id") REFERENCES "fandoms"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vector_documents" ADD CONSTRAINT "vector_documents_novel_id_fkey" FOREIGN KEY ("novel_id") REFERENCES "novels"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "volumes" ADD CONSTRAINT "volumes_novel_id_fkey" FOREIGN KEY ("novel_id") REFERENCES "novels"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "world_settings" ADD CONSTRAINT "world_settings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "world_settings" ADD CONSTRAINT "world_settings_fandom_id_fkey" FOREIGN KEY ("fandom_id") REFERENCES "fandoms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "world_settings" ADD CONSTRAINT "world_settings_novel_id_fkey" FOREIGN KEY ("novel_id") REFERENCES "novels"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "writing_styles" ADD CONSTRAINT "writing_styles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "writing_styles" ADD CONSTRAINT "writing_styles_novel_id_fkey" FOREIGN KEY ("novel_id") REFERENCES "novels"("id") ON DELETE CASCADE ON UPDATE CASCADE;
