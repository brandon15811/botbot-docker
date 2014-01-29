#!/bin/bash
#Not suitable for use outside of docker
set -xe
#Store directory where script was executed
DIR=$PWD
#Enable ubuntu universe repo
echo "deb http://archive.ubuntu.com/ubuntu precise main universe" > /etc/apt/sources.list
apt-get update
#Set frontend to noninteractive so go doesn't prompt for stats collection stuff
bash -c "DEBIAN_FRONTEND=noninteractive apt-get -y install redis-server postgresql postgresql-contrib postgresql-server-dev-9.1 curl wget build-essential python2.7-dev git python-pip python-virtualenv golang-go sudo makepasswd expect"
service redis-server start
service postgresql start
sudo -u postgres createuser -s -d -r root
createuser -S -D -R -e botbot
createdb -O botbot botbot
#TODO: Move password generation to start command (for docker)
BOTBOTDB_PASS=$(makepasswd --chars=25)
echo "ALTER USER botbot WITH PASSWORD '$BOTBOTDB_PASS';" | psql botbot
#Needed by botbot
echo "create extension hstore" | psql botbot
mkdir -p $DIR/botbot
cd $DIR/botbot && virtualenv botbot && source botbot/bin/activate
cd $DIR/botbot && pip install -e git+https://github.com/BotBotMe/botbot-web.git#egg=botbot
cd $VIRTUAL_ENV/src/botbot && make $THREADS dependencies
cd $VIRTUAL_ENV/src/botbot && cp .env.example .env
sed -i "s/# DATABASE_URL=postgres:\/\/user:pass@localhost:5432\/name/DATABASE_URL=postgres:\/\/botbot:${BOTBOTDB_PASS}@localhost:5432\/botbot/" $VIRTUAL_ENV/src/botbot/.env
SECRETKEY=$(makepasswd --chars=128)
sed -i "s/SECRET_KEY=supersecretkeyhere/SECRET_KEY=${SECRETKEY}/" $VIRTUAL_ENV/src/botbot/.env
cd $VIRTUAL_ENV/src/botbot && manage.py syncdb --migrate
#Only needed inside docker (honcho fails without the user variable)
export USER="root"
BOTBOTADMIN_PASS=$(makepasswd --chars=25)
#Use "expect" to set django superuser password
echo '#!/usr/bin/expect' > $VIRTUAL_ENV/src/botbot/superuser.expect
echo "spawn manage.py createsuperuser --username=admin --email=admin@host.local" >> $VIRTUAL_ENV/src/botbot/superuser.expect
echo 'expect "Password:"' >> $VIRTUAL_ENV/src/botbot/superuser.expect
echo "send \"${BOTBOTADMIN_PASS}\n\"" >> $VIRTUAL_ENV/src/botbot/superuser.expect
echo "expect \"Password (again): \"" >> $VIRTUAL_ENV/src/botbot/superuser.expect
echo "send \"${BOTBOTADMIN_PASS}\n\"" >> $VIRTUAL_ENV/src/botbot/superuser.expect
echo "expect \"Superuser created successfully.\"" >> $VIRTUAL_ENV/src/botbot/superuser.expect
cd $VIRTUAL_ENV/src/botbot/ && expect superuser.expect
echo "Admin Username: admin"
echo "Admin Password: ${BOTBOTADMIN_PASS}"
#Uncomment this to listen on all interfaces
#sed -i 's/\$WEB_PORT/0.0.0.0:\$WEB_PORT/' $VIRTUAL_ENV/src/botbot/Procfile
#cd $VIRTUAL_ENV/src/botbot && honcho start
