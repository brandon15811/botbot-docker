FROM ubuntu:12.04
MAINTAINER brandon15811
ADD install.sh /botbot/install.sh
RUN bash /botbot/install.sh
ADD start.sh /botbot/start.sh
CMD /botbot/start.sh
WORKDIR /botbot/src/botbot
EXPOSE 8000
