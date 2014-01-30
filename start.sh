#!/bin/bash
#TODO: Don't regenerate password each time (DONE)
#TODO: Set password from env variable
set -ex
service redis-server start
service postgresql start

#Activate virtualenv
source /botbot/botbot/bin/activate
if [ ! -f /botbot/.firstrun ]; then
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
    echo '#!/usr/bin/expect' > $VIRTUAL_ENV/src/botbot/superuserchange.expect
    echo "spawn manage.py changepassword admin" >> $VIRTUAL_ENV/src/botbot/superuserchange.expect
    echo "expect \"Changing password for user 'admin'"\" >> $VIRTUAL_ENV/src/botbot/superuserchange.expect
    echo 'expect "Password:"' >> $VIRTUAL_ENV/src/botbot/superuserchange.expect
    echo "send \"${BOTBOTADMIN_PASS}\n\"" >> $VIRTUAL_ENV/src/botbot/superuserchange.expect
    echo "expect \"Password (again): \"" >> $VIRTUAL_ENV/src/botbot/superuserchange.expect
    echo "send \"${BOTBOTADMIN_PASS}\n\"" >> $VIRTUAL_ENV/src/botbot/superuserchange.expect
    echo "expect \"Password changed successfully for user 'admin'\"" >> $VIRTUAL_ENV/src/botbot/superuserchange.expect
    cd $VIRTUAL_ENV/src/botbot/ && expect superuserchange.expect
    echo "Admin Username: admin"
    echo "Admin Password: ${BOTBOTADMIN_PASS}"
    touch /botbot/.firstrun
fi
exec honcho start
