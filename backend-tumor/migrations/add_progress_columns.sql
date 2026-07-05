-- Migration: Add progress tracking columns to mri_scans
-- Run this SQL inside the PostgreSQL container:
-- docker exec -it <postgres_container> psql -U <user> -d <db> -f /path/to/this/file
-- Or: docker exec -it <container> psql -U <user> -d <db> -c "PASTE SQL BELOW"

ALTER TABLE mri_scans ADD COLUMN IF NOT EXISTS processing_status VARCHAR DEFAULT 'uploaded';
ALTER TABLE mri_scans ADD COLUMN IF NOT EXISTS processing_progress INTEGER DEFAULT 0;
ALTER TABLE mri_scans ADD COLUMN IF NOT EXISTS processing_message VARCHAR;
