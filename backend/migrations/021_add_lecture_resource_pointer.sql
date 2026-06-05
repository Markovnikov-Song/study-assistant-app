ALTER TABLE node_lectures
ADD COLUMN IF NOT EXISTS imported_to_doc_id INTEGER
REFERENCES documents(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_node_lectures_imported_doc
ON node_lectures(imported_to_doc_id);
