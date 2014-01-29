#!/bin/bash
ENV THREADS '-j8'
RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" > /etc/apt/sources.list
RUN apt-get update
#Set frontend to noninteractive so go doesn't prompt for stats collection stuff
RUN bash -c "DEBIAN_FRONTEND=noninteractive apt-get -y install redis-server postgresql postgresql-contrib postgresql-server-dev-9.1 curl wget build-essential python2.7-dev git python-pip python-virtualenv golang-go sudo makepasswd expect"
RUN sudo -u postgres createuser -s -d -r root
RUN createuser -S -D -R -e botbot
RUN createdb -O botbot botbot
#TODO: Move password generation to start command
#FIXME: Password needs to be written into a file and source'ed on each RUN that uses the psql password
RUN BOTBOTDB_PASS=$(makepasswd --chars=25)
RUN echo "ALTER USER botbot WITH PASSWORD '$BOTBOTDB_PASS';" | psql botbot
#Needed by botbot
RUN echo "create extension hstore" | psql botbot
RUN mkdir /botbot
#The Makefile is hardcoded for virtualenv
ENV VIRTUAL_ENV "/botbot"
#No need for virtualenv inside docker?
RUN cd /botbot #&& virtualenv botbot && source botbot/bin/activate
RUN cd /botbot && pip install -e git+https://github.com/BotBotMe/botbot-web.git#egg=botbot
RUN cd $VIRTUAL_ENV/src/botbot && make $THREADS dependencies
RUN cd $VIRTUAL_ENV/src/botbot && cp .env.example .env
RUN sed -i "s/# DATABASE_URL=postgres:\/\/user:pass@localhost:5432\/name/DATABASE_URL=postgres:\/\/botbot:$(makepasswd --chars=25)@localhost:5432\/botbot/" $VIRTUAL_ENV/src/botbot/.env
#RUN SECRETKEY=$(makepasswd --chars=128)
RUN sed -i "s/SECRET_KEY=supersecretkeyhere/SECRET_KEY=$(makepasswd --chars=128)/" $VIRTUAL_ENV/src/botbot/.env
#manage.py fails without this
RUN mkdir -p /botbot/src/botbot/botbot/conf
RUN cd $VIRTUAL_ENV/src/botbot && manage.py syncdb --migrate
#Docker doesn't have the user variable, and honcho fails without this
RUN export USER="root"
#FIXME: Password needs to be written into a file and source'ed on each RUN that uses the admin password
RUN BOTBOTADMIN_PASS=$(makepasswd --chars=25)
RUN echo '#!/usr/bin/expect' > $VIRTUAL_ENV/src/botbot/superuser.expect
RUN echo "spawn manage.py createsuperuser --username=admin --email=admin@host.local" >> $VIRTUAL_ENV/src/botbot/superuser.expect
RUN echo 'expect "Password:"' >> $VIRTUAL_ENV/src/botbot/superuser.expect
RUN echo "send \"${BOTBOTADMIN_PASS}\n\"" >> $VIRTUAL_ENV/src/botbot/superuser.expect
RUN echo "expect \"Password (again): \"" >> $VIRTUAL_ENV/src/botbot/superuser.expect
RUN echo "send \"${BOTBOTADMIN_PASS}\n\"" >> $VIRTUAL_ENV/src/botbot/superuser.expect
RUN echo "expect \"Superuser created successfully.\"" >> $VIRTUAL_ENV/src/botbot/superuser.expect
RUN cd $VIRTUAL_ENV/src/botbot/ && expect superuser.expect
RUN echo "Admin Username: admin"
RUN echo "Admin Password: ${BOTBOTADMIN_PASS}"
RUN sed -i 's/\$WEB_PORT/0.0.0.0:\$WEB_PORT/' $VIRTUAL_ENV/src/botbot/Procfile
ENV PATH $PATH:/usr/lib/go/bin/
RUN cd $VIRTUAL_ENV/src/botbot && honcho start
CMD cd /botbot/src/botbot && honcho start
WORKDIR /botbot/src/botbot
EXPOSE 8000