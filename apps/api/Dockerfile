FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

RUN groupadd --gid 10001 mnovel \
    && useradd --uid 10001 --gid mnovel --no-create-home --shell /usr/sbin/nologin mnovel

COPY pyproject.toml ./
COPY app ./app
RUN pip install --no-cache-dir .

RUN mkdir -p /app/data \
    && chown -R mnovel:mnovel /app

USER mnovel

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/api/v1/health', timeout=3)"]

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1", "--proxy-headers", "--forwarded-allow-ips", "*"]
