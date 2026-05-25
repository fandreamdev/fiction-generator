-- This is an empty migration.
CREATE EXTENSION IF NOT EXISTS vector;

CREATE INDEX IF NOT EXISTS vector_documents_embedding_ivfflat_idx
ON vector_documents
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

CREATE INDEX IF NOT EXISTS vector_documents_scope_idx
ON vector_documents (user_id, fandom_id, novel_id, source_type);