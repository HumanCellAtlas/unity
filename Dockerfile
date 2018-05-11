# use KDUX base Rails image, configure only project-specific items here
FROM broadinstitute/kdux-rails-baseimage:1.2

# Set ruby version
RUN bash -lc 'rvm --default use ruby-2.5.1'

# Set up project dir, install gems, set up script to migrate database and precompile static assets on run
RUN mkdir /home/app/webapp
RUN gem update --system
RUN gem install bundler
COPY Gemfile /home/app/webapp/Gemfile
COPY Gemfile.lock /home/app/webapp/Gemfile.lock
WORKDIR /home/app/webapp
RUN bundle install
COPY set_user_permissions.bash /etc/my_init.d/01_set_user_permissions.bash
COPY generate_dh_parameters.bash /etc/my_init.d/02_generate_dh_parameters.bash
COPY rails_startup.bash /etc/my_init.d/03_rails_startup.bash

# Configure NGINX
RUN rm /etc/nginx/sites-enabled/default
COPY webapp.conf /etc/nginx/sites-enabled/webapp.conf
COPY nginx.conf /etc/nginx/nginx.conf
RUN rm -f /etc/service/nginx/down

# Compile native support for passenger for Ruby 2.2
RUN passenger-config build-native-support

# add yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
RUN sudo apt-get update && sudo apt-get install yarn

# Copy entire source into image rather than mount source
ADD . .
RUN chown -R app:app .