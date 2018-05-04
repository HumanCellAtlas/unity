#!/bin/bash

cd /home/app/webapp
echo "*** ROLLING OVER LOGS ***"
ruby /home/app/webapp/bin/cycle_logs.rb
echo "*** COMPLETED ***"
echo "*** CLEARING TMP CACHE ***"
sudo -E -u app -H bundle exec rake RAILS_ENV=$PASSENGER_APP_ENV tmp:clear
echo "*** COMPLETED ***"

echo "*** INITIALIZING & MIGRATING DATABASE ***"
sudo -E -u app -H bundle exec rake RAILS_ENV=$PASSENGER_APP_ENV db:exists && rake RAILS_ENV=$PASSENGER_APP_ENV db:migrate || rake RAILS_ENV=$PASSENGER_APP_ENV db:setup
echo "*** COMPLETED ***"

echo "*** CREATING CRON ENV FILES ***"
echo "export SENDGRID_USERNAME=$SENDGRID_USERNAME" >> /home/app/.cron_env
echo "export SENDGRID_PASSWORD=$SENDGRID_PASSWORD" >> /home/app/.cron_env
echo "export DATABASE_HOST=$DATABASE_HOST" >> /home/app/.cron_env
echo "export DATABASE_USER=$DATABASE_USER" >> /home/app/.cron_env
echo "export DATABASE_PASSWORD=$DATABASE_PASSWORD" >> /home/app/.cron_env
if [[ -z $SERVICE_ACCOUNT_KEY ]]; then
	echo $GOOGLE_CLOUD_KEYFILE_JSON >| /home/app/.google_service_account.json
	chmod 400 /home/app/.google_service_account.json
	chown app:app /home/app/.google_service_account.json
	echo "export SERVICE_ACCOUNT_KEY=/home/app/.google_service_account.json" >> /home/app/.cron_env
else
	echo "export SERVICE_ACCOUNT_KEY=$SERVICE_ACCOUNT_KEY" >> /home/app/.cron_env
fi

chmod 400 /home/app/.cron_env
chown app:app /home/app/.cron_env
echo "*** COMPLETED ***"

if [[ ! -d /home/app/webapp/tmp/pids ]]
then
	echo "*** MAKING TMP DIR ***"
	sudo -E -u app -H mkdir -p /home/app/webapp/tmp/pids
	echo "*** COMPLETED ***"
fi