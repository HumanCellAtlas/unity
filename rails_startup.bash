#!/bin/bash

cd /home/app/webapp
echo "*** ROLLING OVER LOGS ***"
ruby /home/app/webapp/bin/cycle_logs.rb
echo "*** COMPLETED ***"
echo "*** CLEARING TMP CACHE ***"
sudo -E -u app -H bundle exec rake RAILS_ENV=$PASSENGER_APP_ENV tmp:clear
echo "*** COMPLETED ***"
if [[ $PASSENGER_APP_ENV = "production" ]];
then
    echo "*** PRECOMPILING ASSETS ***"
    sudo -E -u app -H bundle exec rake RAILS_ENV=$PASSENGER_APP_ENV assets:clean
    sudo -E -u app -H bundle exec rake RAILS_ENV=$PASSENGER_APP_ENV assets:precompile
    echo "*** COMPLETED ***"
fi
echo "*** INITIALIZING & MIGRATING DATABASE ***"
sudo -E -u app -H bundle exec rake RAILS_ENV=$PASSENGER_APP_ENV db:exists && rake RAILS_ENV=$PASSENGER_APP_ENV db:migrate || rake RAILS_ENV=$PASSENGER_APP_ENV db:setup
echo "*** COMPLETED ***"

echo "*** CREATING CRON ENV FILES ***"
echo "export SENDGRID_USERNAME=$SENDGRID_USERNAME" >> /home/app/webapp/.cron_env
echo "export SENDGRID_PASSWORD=$SENDGRID_PASSWORD" >> /home/app/webapp/.cron_env
echo "export DATABASE_HOST=$DATABASE_HOST" >> /home/app/webapp/.cron_env
echo "export DATABASE_USER=$DATABASE_USER" >> /home/app/webapp/.cron_env
echo "export DATABASE_PASSWORD=$DATABASE_PASSWORD" >> /home/app/webapp/.cron_env
if [[ -z $SERVICE_ACCOUNT_KEY ]]; then
	echo "export GOOGLE_CLOUD_KEYFILE_JSON=$GOOGLE_CLOUD_KEYFILE_JSON" >> /home/app/webapp/.cron_env
	echo "export GOOGLE_CLOUD_PROJECT=$GOOGLE_CLOUD_PROJECT" >> /home/app/webapp/.cron_env
else
	echo "export SERVICE_ACCOUNT_KEY=$SERVICE_ACCOUNT_KEY" >> /home/app/webapp/.cron_env
fi

chmod 400 /home/app/webapp/.cron_env
chown app:app /home/app/webapp/.cron_env
echo "*** COMPLETED ***"

echo "*** ADDING API HEALTH CRONTAB ***"
echo "*/5 * * * * . /home/app/webapp/.cron_env ; cd /home/app/webapp/; /home/app/webapp/bin/rails runner -e $PASSENGER_APP_ENV \"AdminConfiguration.check_api_health\" >> /home/app/webapp/log/cron_out.log 2>&1" | crontab -u app -
echo "*** COMPLETED ***"

if [[ ! -d /home/app/webapp/tmp/pids ]]
then
	echo "*** MAKING TMP DIR ***"
	sudo -E -u app -H mkdir -p /home/app/webapp/tmp/pids
	echo "*** COMPLETED ***"
fi

ln -sf /dev/stdout /var/log/nginx/error.log