FROM zakharbz/labshock-scada:v1.1.0


# entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# app data files
COPY ./appdata /usr/src/app/FUXA/server/_appdata

# start app
ENTRYPOINT ["/entrypoint.sh"]
CMD ["docker-entrypoint.sh", "npm", "start"]