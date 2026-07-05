# run_migration.py
from database import engine
from sqlalchemy import text

print("Memulai migrasi database...")
queries = [
    "ALTER TABLE mri_scans ADD COLUMN IF NOT EXISTS processing_status VARCHAR DEFAULT 'uploaded';",
    "ALTER TABLE mri_scans ADD COLUMN IF NOT EXISTS processing_progress INTEGER DEFAULT 0;",
    "ALTER TABLE mri_scans ADD COLUMN IF NOT EXISTS processing_message VARCHAR;"
]

with engine.connect() as conn:
    for query in queries:
        try:
            conn.execute(text(query))
            conn.commit()
            print(f"Sukses eksekusi: {query}")
        except Exception as e:
            print(f"Error eksekusi '{query}': {e}")

print("Migrasi selesai!")
