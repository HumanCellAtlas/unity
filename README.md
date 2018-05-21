# UNITY BENCHMARK SERVICE README
UNITY is a workflow benchmarking platform used for developing and comparing pipelines.

## SETUP

This application is built and deployed using [Docker](https://www.docker.com), specifically native [Docker for Mac OSX](https://docs.docker.com/docker-for-mac/).
Please refer to their online documentation for instructions on installing and creating a default VM for managing Docker images.

## BUILDING THE DOCKER IMAGE

Once all source files are checked out and Docker has been installed and your VM configured, open a terminal window and execute the following steps:

1. Navigate to the project directory
2. Build the Unity Benchmark image: <code>docker build -t unity_benchmark_docker:[version_number] -f Dockerfile .</code>

This will start the automated process of building the Docker image for running the service.  The image is built off of
the [Passenger-docker baseimage](https://github.com/phusion/passenger-docker) and comes with Ruby, Nginx, and Passenger
by default, with additional packages added to the [Broad Institute KDUX Rails baseimage](https://hub.docker.com/r/broadinstitute/kdux-rails-baseimage/)
which pulls from the original baseimage.

<em>If this is your first time building the image, it may take several minutes to download and install everything.</em>

## BEFORE RUNNING THE CONTAINER IN DEVELOPMENT

Since this project utilizes native Docker for Mac OSX, any resources on the host machine cannot be reached by the running
container (specifically, any database resources). Therefore, we will need to deploy a database container using Docker
as well.  This project uses [postgres](https://hub.docker.com/_/postgres/) as the primary datastore.

First, create a directory somewhere on your computer in which to store the raw database content (it doesn't matter where
as long as it has <code>rw</code> permissions, but preferably it would be inside your home directory).

To deploy the database container:

1. Pull the image: <code>docker pull postgres</code>
2. Navigate to the project directory
3. Run the helper script to start the DB container: <code>bin/boot_postgres -d (path to data store directory) -u (postgres username) -p (postgres password)</code>

Note: Once the container has been run once, you can stop & restart it using: <code>docker stop postgres</code> or
<code>docker restart postgres</code>

When deploying the service in production, the application will connect to a remote DB host that must be provisioned and configured separately.

## DEPLOYING A PRIVATE INSTANCE

If you are deploying a private instance of the Unity Benchmark Service, there are a few extra steps that need to be taken before the
portal is configured and ready to use:

* <b>Create a GCP project</b>: Even if you are deploying locally or in a private cluster, the portal requires a Google Cloud Plaform project in order to handle OAuth callbacks and service account credentials.  To create your project:
  * Visit https://console.developers.google.com
  * Click 'Select a project' in the top lefthand corner and click the + button
  * Name your new project and save
* <b>OAuth Credentials</b>: Once your project is created, you will need to create an OAuth Client ID in order to allow users to log in with their Google accounts.  To do so:
  * Log into your new GCP project
  * Click the navigation menu in the top left and select 'APIs & Services' > 'Credentials'
  * Click 'Create Credentials' > 'OAuth Client ID'
  * Select 'Web Application', and provide a name
  * For 'Authorized Javascript Origins', enter <code>https://(your hostname)/unity</code>
  * For 'Authorized redirect URIs', enter <code>https://(your hostname)/unity/omniauth/google_oauth2/callback</code>
  * Save the client id
* <b>GCP Service Account keys</b>: Regardless of where the portal is deployed, it requires a Google Cloud Platform Service Account in order to make authenticated calls into FireCloud and Google Cloud Storage.  Therefore, you must export the default service account key.  See https://developers.google.com/identity/protocols/OAuth2ServiceAccount for more information about service accounts.  To export the credentials:
  * Log into your new GCP project
  * Click the navigation menu in the top left and select 'IAM & Admin	' > 'Service Accounts'
  * On entry 'Compute Engine default service account', click the 'Options' menu (far right) and select 'Create key'
  * Select 'JSON' and export and save the key locally
* <b>Enable GCP APIs</b>: The following Google Cloud Platform APIs must be enabled:
  * Google Compute Engine API
  * Google Cloud APIs
  * Google Cloud Billing API
  * Google Cloud Storage JSON API
  * Google+ API
  * Kubernetes Engine API (if deploying via Kubernetes)
* <b>Registering your Service Account as a FireCloud user</b>: Once you have configured and booted your instance of the portal, you will need to register your service account as a FireCloud user in order to create a billing project and create studies.  To do so:
  * TBD

## RUNNING THE CONTAINER

Once the image has successfully built and the database container is running, use the following command to start the container:
<pre>bin/boot_docker -u (sendgrid username) -P (sendgrid password) -k (service account key path) -o (oauth client id) -S (oauth client secret) -l</pre>

This sets up several environment variables in your shell and then runs the following command:
<pre>docker run --rm -it --name $CONTAINER_NAME --link $DATABASE_HOST:$DATABASE_HOST -p 80:80 -p 443:443 -h localhost -v $PROJECT_DIR:/home/app/webapp:rw -e PASSENGER_APP_ENV=$PASSENGER_APP_ENV -e DATABASE_HOST=$DATABASE_HOST -e DATABASE_USER=$DATABASE_USER -e PROD_DATABASE_PASSWORD=$DATABASE_PASSWORD -e SERVICE_ACCOUNT_KEY=$SERVICE_ACCOUNT_KEY -e SENDGRID_USERNAME=$SENDGRID_USERNAME -e SENDGRID_PASSWORD=$SENDGRID_PASSWORD -e SECRET_KEY_BASE=$SECRET_KEY_BASE -e OAUTH_CLIENT_ID=$OAUTH_CLIENT_ID -e OAUTH_CLIENT_SECRET=$OAUTH_CLIENT_SECRET -e GOOGLE_CLOUD_KEYFILE_JSON="$GOOGLE_CLOUD_KEYFILE_JSON" -e GOOGLE_PRIVATE_KEY="$GOOGLE_PRIVATE_KEY" -e GOOGLE_CLIENT_EMAIL="$GOOGLE_CLIENT_EMAIL" -e GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID" -e GOOGLE_CLOUD_PROJECT="$GOOGLE_CLOUD_PROJECT" unity_benchmark_docker:$DOCKER_IMAGE_VERSION</pre>

The container will then start running, and will execute its local startup scripts that will configure the application automatically.

You can also run the <code>bin/boot_docker</code> script in help mode by passing <code>-H</code> to print the help text
which will show you how to pass specific values to the above env variables.  <em>Note: running the shortcut script with
an environment of 'production' will cause the container to spawn headlessly by passing the <code>-d</code> flag, rather
than <code>--rm -it</code>.</em>

### DOCKER RUN COMMAND ENVIRONMENT VARIABLES
There are several variables that need to be passed to the Docker container in order to run properly:
1. *CONTAINER_NAME* (passed with --name): This names your container to whatever you want.  This is useful when linking containers.
3. *PROJECT_DIR* (passed with -v): This mounts your local working directory inside the Docker container.  Makes doing local development via hot deployment possible.
4. *PASSENGER_APP_ENV* (passed with -e): The Rails environment you wish to load.  Can be either development, test, or production (default is development).
5. *DATABASE_HOST* (passed with -e): Name of the container running postgres.  Even though our two containers are linked, this needs to be set to allow Rails to communicate with the database.
5. *DATABASE_USER* (passed with -e): Name of the container running postgres.  Even though our two containers are linked, this needs to be set to allow Rails to communicate with the database.
5. *DATABASE_PASSWORD* (passed with -e): Name of the container running postgres.  Even though our two containers are linked, this needs to be set to allow Rails to communicate with the database.
6. *SENDGRID_USERNAME* (passed with -e): The username associated with a Sendgrid account (for sending emails).
7. *SENDGRID_PASSWORD* (passed with -e): The password associated with a Sendgrid account (for sending emails).
8. *SECRET_KEY_BASE* (passed with -e): Sets the Rails SECRET_KEY_BASE environment variable, used mostly by Devise in authentication for cookies.
9. *SERVICE_ACCOUNT_KEY* (passed with -e): Sets the SERVICE_ACCOUNT_KEY environment variable, used for making authenticated API calls to FireCloud & GCP.
10. *OAUTH_CLIENT_ID* (passed with -e): Sets the OAUTH_CLIENT_ID environment variable, used for Google OAuth2 integration.
11. *OAUTH_CLIENT_SECRET* (passed with -e): Sets the OAUTH_CLIENT_SECRET environment variable, used for Google OAuth2 integration.
12. *GOOGLE_[VARIOUS]* (passed with -e): If no SERVICE_ACCOUNT_KEY is present, the application will default to using the standard OAuth2 enviroment variables for authentication.  See [here](https://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-storage/v0.23.2/guides/authentication) for more information.
13. *DOCKER_IMAGE_VERSION*: sets the version of the unity_benchmark_docker image to use (defaults to _latest_)

### RUN COMMAND IN DETAIL
The run command explained in its entirety:
* *--rm:* This tells Docker to automatically clean up the container after exiting.
* *-it:* Leaves an interactive shell running in the foreground where the output of Nginx can be seen.
* <b>--name CONTAINER_NAME:</b> This names your container to whatever you want.  This is useful when linking other Docker containers to the portal container, or when connecting to a running container to check logs or environment variables.  The default is <b>unity_benchmark</b>.
* <b>-p 80:80 -p 443:443 -p 587:587:</b> Maps ports 80 (HTTP), 443 (HTTPS), and 587 (smtp) on the host machine to the corresponding ports inside the Docker container.
* <b>--link $DATABASE_HOST:$DATABASE_HOST</b>: Connects our webapp container to the postgres container, creating a virtual hostname inside the unity_benchmark container called postgres.
* <b>-v [PROJECT_DIR]/:/home/app/webapp:</b> This mounts your local working directory inside the running Docker container in the correct location for the portal to run.  This accomplishes two things:
  - Enables hot deployment for local development
  - Persists all project data past destruction of Docker container (since we're running with --rm), but not system-level log or tmp files.
* <b>-e PASSENGER_APP_ENV= [RAILS_ENV]:</b> The Rails environment.  Will default to development, so if you're doing a production deployment, set this accordingly.
* <b>-e DATABASE_HOST= [DATABASE_HOST]:</b> Name of the container running postgres.  Even though our two containers are linked, this needs to be set to allow Rails to communicate with the database.
* <b>-e DATABASE_USER= [DATABASE_USER] -e DATABASE_PASSWORD= [DATABASE_PASSWORD]:</b> Credentials for authenticating into postgres.
* <b>-e SENDGRID_USERNAME= [SENDGRID_USERNAME] -e SENDGRID_PASSWORD= [SENDGRID_PASSWORD]:</b> The credentials for Sendgrid to send emails.  Alternatively, you could decide to not use Sendgrid and configure the application to use a different SMTP server (would be done inside your environment's config file).
* <b>-e SECRET_KEY_BASE= [SECRET_KEY_BASE]:</b> Setting the SECRET_KEY_BASE variable is necessary for creating secure cookies for authentication.  This variable automatically resets every time we restart the container.
* <b>-e SERVICE_ACCOUNT_KEY= [SERVICE_ACCOUNT_KEY]:</b> Setting the SERVICE_ACCOUNT_KEY variable is necessary for making authenticated API calls to FireCloud and GCP.  This should be a file path <b>relative to the app root</b> that points to the JSON service account key file you exported from GCP.
* <b>-e OAUTH_CLIENT_ID= [OAUTH_CLIENT_ID] -e OAUTH_CLIENT_SECRET= [OAUTH_CLIENT_SECRET]:</b> Setting the OAUTH_CLIENT_ID and OAUTH_CLIENT_SECRET variables are necessary for allowing Google user authentication.  For instructions on creating OAuth 2.0 Client IDs, refer to the [Google OAuth 2.0 documentation](https://support.google.com/cloud/answer/6158849).
* *unity_benchmark_docker*: This is the name of the image we created earlier.  If you chose a different name, please use that here.
* *$DOCKER_IMAGE_VERSION*: Version number of the above Docker image.

## TESTS

TBD

## PRODUCTION DEPLOYMENT

### KUBERNETES

Unity is designed to be deployed via [Kubernetes](https://kubernetes.io), although this is not the only way that Unity can be deployed (see below for details). 
To deploy Unity in Kubernetes, you will need the following prerequisites:
* A Kubernetes cluster already [created](https://cloud.google.com/kubernetes-engine/docs/quickstart#create_cluster) in your GCP project
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) installed
* Set your local kubernetes config to [point at your remote cluster](https://cloud.google.com/sdk/gcloud/reference/container/clusters/get-credentials):
  * <code>gcloud container clusters get-credentials NAME -z ZONE</code>
  
Once your cluster is running and <code>kubectl</code> is pointing at your remote cluster:
1. Navigate to the project directory
2. Create the deployment: <code>kubectl apply -f config/unity-benchmark-deployment.yaml</code>
3. Create the service: <code>kubectl apply -f config/unity-benchmark-service.yaml</code>
4. Once your service is running, get the EXTERNAL-IP address: <code>kubectl get service unity-benchmark-service</code>
5. You can change the external IP from ephemeral to static inside your VPC Network > [External IP Addresses](https://console.cloud.google.com/networking/addresses/list) console in GCP

Unity will now be available publicly on the above IP address.

### OTHER DEPLOYMENTS

Unity can also be deployed on any infrastructure that will support [Docker](https://www.docker.com).  This could be on 
Google Cloud Platform, Amazon Web Services, or any other provider/operating system where Docker can be installed.  For instructions 
on how to deploy, provision a virtual machine, install Docker, and then follow the instructions for 'RUNNING THE CONTAINER', 
with the difference of adding <code>-e production</code> to <code>bin/boot_docker</code>.

The Unity database can be deployed either as a linked docker container (as in development, see 'BEFORE RUNNING THE CONTAINER IN DEVELOPMENT' 
for more info, then linked by passing <code>-l</code> to <code>bin/boot_docker</code>) or a as a separate host, via <code>-m [DATABASE HOST]</code>.  

### FIRECLOUD INTEGRATION

The Unity Benchmark Service utilizes [FireCloud](https://software.broadinstitute.org/firecloud/) for storing data and launching workflow
submissions, which in turn store raw files in GCP buckets.  This is all managed through a GCP service account which in turn owns all portal workspaces
and manages them on behalf of users.  This is why your service account must be registered as a FireCloud user before the service 
can function correctly.
