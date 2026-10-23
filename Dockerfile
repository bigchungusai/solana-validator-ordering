FROM python:3.11-slim
WORKDIR /app
RUN pip install --no-cache-dir requests numpy scipy
COPY measure_scheduler.py /app/measure_scheduler.py
COPY data /app/data
ENTRYPOINT ["python3", "measure_scheduler.py"]
CMD ["--dry-run"]
