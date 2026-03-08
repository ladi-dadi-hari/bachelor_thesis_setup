FROM zakharbz/labshock-collector:v2.0.1

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

COPY ./config.json /app/config
COPY ./sources.json /app/config

WORKDIR /app
CMD ["sh", "-c", "nginx -g 'daemon off;' & python3 start.py"]
