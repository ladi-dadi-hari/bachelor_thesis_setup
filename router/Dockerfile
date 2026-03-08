FROM zakharbz/labshock-router:v2.0.4

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

COPY ./rules.json /app/config
COPY ./config.json /app/config

WORKDIR /app
CMD ["sh", "-c", "nginx -g 'daemon off;' & python3 start.py"]
