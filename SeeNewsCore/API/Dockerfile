FROM python:3.12-slim

WORKDIR /app

# System deps for psycopg2
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev gcc \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY server.py .
COPY api_utils.py .
COPY notifications.py .

# Cloud Run provides PORT env var; default 8080
ENV PORT=8080

EXPOSE 8080

CMD ["python", "server.py"]
