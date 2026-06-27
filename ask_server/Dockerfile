# Container image for the /ask service (Cloud Run or any container host).
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app ./app
COPY ingest ./ingest

# Cloud Run injects PORT; default 8080 for a local `docker run`.
ENV PORT=8080
EXPOSE 8080

# ASK_STUB defaults to 1 in code. For real answers set, at deploy time:
#   ASK_STUB=0  GEMINI_API_KEY=...  ASK_STORE=fileSearchStores/...
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}"]
