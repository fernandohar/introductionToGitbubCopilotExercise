FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PORT=7860

COPY StockAnalyzer/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY StockAnalyzer/app ./app
COPY StockAnalyzer/static ./static
COPY StockAnalyzer/data ./data

EXPOSE 7860

CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT}
