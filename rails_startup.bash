#!/bin/bash

cd /home/app/webapp
echo "*** ROLLING OVER LOGS ***"
ruby /home/app/webapp/bin/cycle_logs.rb
echo "*** COMPLETED ***"
if [[ $PASSENGER_APP_ENV -ne "production" ]]; then
    echo "*** WRITING ENCRYPTED CREDENTIALS ***"
    echo "secret_key_base: $SECRET_KEY_BASE" | RAILS_ENV=$PASSENGER_APP_ENV EDITOR="vi -w" bin/rails credentials:edit
    echo "*** COMPLETED ***"
fi
echo "*** CLEARING TMP CACHE ***"
sudo -E -u app -H bundle exec rake RAILS_ENV=$PASSENGER_APP_ENV tmp:clear
echo "*** COMPLETED ***"
if [[ $PASSENGER_APP_ENV = "production" ]];
then
    echo "*** PRECOMPILING ASSETS ***"
    sudo -E -u app -H bundle exec rake RAILS_ENV=$PASSENGER_APP_ENV assets:clean
    sudo -E -u app -H bundle exec rake RAILS_ENV=$PASSENGER_APP_ENV assets:precompile
    sudo -E -u app -H bundle exec rake RAILS_ENV=$PASSENGER_APP_ENV yarn:install
    sudo -E -u app -H bundle exec rake RAILS_ENV=$PASSENGER_APP_ENV webpacker:compile
    echo "*** COMPLETED ***"
elif [[ $PASSENGER_APP_ENV = "development" ]];
then
    echo "*** COMPILING WEBPACK ASSETS ***"
    sudo -E -u app -H bin/webpack
    echo "*** COMPLETED ***"
fi
echo "*** INITIALIZING & MIGRATING DATABASE ***"
sudo -E -u app -H bundle exec rake RAILS_ENV=$PASSENGER_APP_ENV db:exists && rake RAILS_ENV=$PASSENGER_APP_ENV db:migrate || rake RAILS_ENV=$PASSENGER_APP_ENV db:setup
echo "*** COMPLETED ***"

echo "*** CREATING CRON ENV FILES ***"
if [[ -f /home/app/webapp/.cron_env ]]; then
		sudo -E -u app -H rm -f /home/app/webapp/.cron_env
fi
if [[ -f /home/app/webapp/.google_service_account.json ]]; then
		sudo -E -u app -H rm -f /home/app/webapp/.google_service_account.json
fi
if [[ -f /home/app/webapp/.gcs_admin_service_account.json ]]; then
		sudo -E -u app -H rm -f /home/app/webapp/.gcs_admin_service_account.json
fi
echo "export SENDGRID_USERNAME=$SENDGRID_USERNAME" >> /home/app/webapp/.cron_env
echo "export SENDGRID_PASSWORD=$SENDGRID_PASSWORD" >> /home/app/webapp/.cron_env
echo "export DATABASE_HOST=$DATABASE_HOST" >> /home/app/webapp/.cron_env
echo "export DATABASE_USER=$DATABASE_USER" >> /home/app/webapp/.cron_env
echo "export DATABASE_PASSWORD=$DATABASE_PASSWORD" >> /home/app/webapp/.cron_env
echo "export SECRET_KEY_BASE=$SECRET_KEY_BASE" >> /home/app/webapp/.cron_env
if [[ -z $SERVICE_ACCOUNT_KEY ]]; then
	echo $GOOGLE_CLOUD_KEYFILE_JSON >| /home/app/webapp/.google_service_account.json
	chmod 400 /home/app/webapp/.google_service_account.json
	chown app:app /home/app/webapp/.google_service_account.json
	echo "export SERVICE_ACCOUNT_KEY=/home/app/webapp/.google_service_account.json" >> /home/app/webapp/.cron_env
else
	echo "export SERVICE_ACCOUNT_KEY=$SERVICE_ACCOUNT_KEY" >> /home/app/webapp.cron_env
fi

if [[ -n $GCS_ADMIN_GOOGLE_CLOUD_KEYFILE_JSON ]]; then
	echo "*** WRITING GCS ADMIN SERVICE ACCOUNT CREDENTIALS ***"
	echo $GCS_ADMIN_GOOGLE_CLOUD_KEYFILE_JSON >| /home/app/webapp/.gcs_admin_service_account.json
	echo "export GCS_ADMIN_SERVICE_ACCOUNT_KEY=/home/app/webapp/.gcs_admin_service_account.json" >> /home/app/.cron_env
	chmod 400 /home/app/webapp/.gcs_admin_service_account.json
	chown app:app /home/app/webapp/.gcs_admin_service_account.json
elif [[ -n $GCS_ADMIN_SERVICE_ACCOUNT_KEY ]]; then
  echo "*** USING GCS_ADMIN_SERVICE_ACCOUNT CREDENTIALS ***"
	echo "export GCS_ADMIN_SERVICE_ACCOUNT_KEY=$GCS_ADMIN_SERVICE_ACCOUNT_KEY" >> /home/app/.cron_env
else
  echo "*** NO GCS ADMIN SERVICE ACCOUNT DETECTED - DOWNLOADS WILL NOT FUNCTION ***"
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