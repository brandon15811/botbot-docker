FROM ubuntu:12.04
MAINTAINER brandon15811
ADD install.sh /botbot/install.sh
RUN bash install.sh
CMD cd /botbot && source botbot/bin/activate && honcho start
WORKDIR /botbot/src/botbot
EXPOSE 8000