FROM python:3.12-slim AS base

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .


FROM base AS test
COPY requirements-dev.txt pytest.ini ./
COPY tests ./tests
RUN pip install --no-cache-dir -r requirements-dev.txt
CMD ["pytest", "-q"]


FROM base AS runtime
EXPOSE 5000
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
