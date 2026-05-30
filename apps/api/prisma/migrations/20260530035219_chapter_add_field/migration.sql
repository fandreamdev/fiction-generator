-- AlterTable
ALTER TABLE "chapters" ADD COLUMN     "appearing_character_ids" INTEGER[] DEFAULT ARRAY[]::INTEGER[],
ADD COLUMN     "extra_notes" TEXT,
ADD COLUMN     "goal" TEXT;
