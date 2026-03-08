FROM python:3.12-slim
RUN pip install --no-cache-dir pymodbus==3.7.4
WORKDIR /app
COPY sensor_sim.py /app/sensor_sim.py
CMD ["python", "/app/sensor_sim.py"]
