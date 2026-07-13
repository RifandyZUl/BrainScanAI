# Gunakan Python 3.10 slim (stabil untuk AI)
FROM python:3.10-slim

# Set direktori kerja di dalam container
WORKDIR /app

# Instal dependensi sistem
RUN apt-get update && apt-get install -y \
    build-essential \
    libgl1 \
    libglib2.0-0 \
    git \
    && rm -rf /var/lib/apt/lists/*

# Salin file requirements
COPY requirements.txt .

# Instal PyTorch CPU-only terlebih dahulu dari index resmi PyTorch
# (hindari mengunduh versi CUDA yang sangat besar dari PyPI)
RUN pip install --no-cache-dir \
    --timeout=120 \
    --retries=5 \
    "numpy<2.0" \
    torch==2.5.1+cpu \
    torchvision==0.20.1+cpu \
    --index-url https://download.pytorch.org/whl/cpu


# Instal sisa library Python
RUN pip install --no-cache-dir \
    -i https://pypi.tuna.tsinghua.edu.cn/simple \
    --timeout=120 \
    --retries=5 \
    fastapi \
    uvicorn \
    python-multipart \
    sqlalchemy \
    psycopg2-binary \
    "passlib[bcrypt]" \
    "bcrypt==3.2.2" \
    "python-jose[cryptography]" \
    python-dotenv \
    "monai==1.3.0" \
    nibabel \
    scikit-image \
    scipy \
    "einops==0.7.0" \
    "timm==0.9.12" \
    matplotlib \
    plotly \
    Pillow \
    "numpy<2.0" \
    pytz





# Salin sisa kode backend
COPY . .

# Ekspos port 8000 agar bisa diakses dari luar
EXPOSE 8000

# Jalankan FastAPI
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]