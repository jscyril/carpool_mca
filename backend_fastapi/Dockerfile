FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system deps for psycopg2 and geoalchemy2
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source
COPY backend/app .

# Expose port
EXPOSE 8000

# Run with uvicorn (production: 4 workers)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
