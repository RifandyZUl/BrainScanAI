import os
# pyrefly: ignore [missing-import]
from celery import Celery

REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379/0")

celery_app = Celery(
    "tasks",
    broker=REDIS_URL,
    backend=REDIS_URL
)

# Celery configurations
celery_app.conf.update(
    task_track_started=True,
    timezone='Asia/Jakarta',
)

@celery_app.task(name="tasks.process_mri_ai_task")
def process_mri_ai_task(scan_id: int, input_dir: str, output_dir: str, case_id: str, gt_file_path: str, model_type: str):
    print(f"[CELERY WORKER] Memulai pemrosesan asinkron untuk scan ID: {scan_id}")
    from main import process_mri_ai
    process_mri_ai(scan_id, input_dir, output_dir, case_id, gt_file_path, model_type)
    print(f"[CELERY WORKER] Selesai memproses scan ID: {scan_id}")
