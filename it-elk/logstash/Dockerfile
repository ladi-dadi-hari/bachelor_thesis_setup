FROM docker.elastic.co/logstash/logstash:8.14.1
RUN rm -f /usr/share/logstash/pipeline/logstash.conf
COPY ./pipeline/syslog.conf /usr/share/logstash/pipeline/


