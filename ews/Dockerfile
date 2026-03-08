FROM zakharbz/labshock-ews:v1.0.0


# entrypoint
USER root
COPY entrypoint.sh /entrypoint.sh
COPY start-vnc.sh /home/engineer/start-vnc.sh
RUN chmod +x /entrypoint.sh
RUN chmod +x /home/engineer/start-vnc.sh

# start app
ENTRYPOINT ["/entrypoint.sh"]

# patch
COPY ./plc/ /home/engineer/Desktop/PLC/
COPY ./scada/ /home/engineer/Desktop/SCADA/

CMD ["/bin/bash", "-c", "su - engineer -c '/home/engineer/start-vnc.sh'"]
