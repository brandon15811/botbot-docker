#!/bin/bash
set -ex
service redis-server start
service postgresql start

#Activate virtualenv
source /botbot/botbot/bin/activate

#Reset .env config
cp .env.example .env

#Set database password
BOTBOTDB_PASS=$(makepasswd --chars=25)
echo "ALTER USER botbot WITH PASSWORD '$BOTBOTDB_PASS';" | psql botbot
sed -i "s/# DATABASE_URL=postgres:\/\/user:pass@localhost:5432\/name/DATABASE_URL=postgres:\/\/botbot:${BOTBOTDB_PASS}@localhost:5432\/botbot/" $VIRTUAL_ENV/src/botbot/.env

#Set Django secret key
SECRETKEY=$(makepasswd --chars=128)
sed -i "s/SECRET_KEY=supersecretkeyhere/SECRET_KEY=${SECRETKEY}/" $VIRTUAL_ENV/src/botbot/.env
manage.py syncdb --migrate

if [ -z "$USER" ]; then
    export USER="root"
fi

#Set Django admin password
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

honcho start
