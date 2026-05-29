-- Migration 020: per-subject card accent color index

ALTER TABLE subjects
    ADD COLUMN IF NOT EXISTS color_index INTEGER;
