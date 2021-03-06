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
  * For 'Authorized Javascript Origins', enter <code>https://(your hostname)/</code>
  * For 'Authorized redirect URIs', enter <code>https://(your hostname)//omniauth/google_oauth2/callback</code>
  * Save the client id
* <b>Whitelisting your OAuth Audience</b>
	* Once you have exported your OAuth credentials, you will need to have your client id whitelisted to allow it to make
	  authenticated requests into the FireCloud API as per [OpenID Connect 1.0](http://openid.net/specs/openid-connect-core-1_0.html#IDTokenValidation)
	* Send an email to <b>dsp-devops@broadinstitute.org</b> with your OAuth2 client ID so it can be added to the whitelist
* <b>GCP Service Account keys</b>: Regardless of where the portal is deployed, it requires three Google Cloud Platform Service Accounts in order to make authenticated calls into FireCloud, Google Cloud Storage, and Cloud SQL (if deploying in Kubernetes).  Therefore, you must create these service account keys:
.  See https://developers.google.com/identity/protocols/OAuth2ServiceAccount for more information about service accounts.  To export the credentials:
  * Log into your new GCP project
  * Click the navigation menu in the top left and select 'IAM & Admin	' > 'Service Accounts'
  * On entry 'Compute Engine default service account', click the 'Options' menu (far right) and select 'Create key'
  * Select 'JSON' and export and save the key locally
  * Next, create two new service accounts with the following roles and export the keys:
    * Storage Admin
    * Cloud SQL Client (this key is only needed for Kubernetes-based deployments)
* <b>Enable GCP APIs</b>: The following Google Cloud Platform APIs must be enabled:
  * Google Compute Engine API
  * Google Cloud APIs
  * Google Cloud Billing API
  * Google Cloud Storage JSON API
  * Google+ API
  * Kubernetes Engine API (if deploying via Kubernetes)
* <b>Registering your Service Account as a FireCloud user</b>: Once you have configured and booted your instance of the portal, you will need to register your service account as a FireCloud user in order to interact with the FireCloud API.  To do so:
  1. Attach to the running instance of Unity (preferably a local instance in development mode, but can be a deployed instance) <pre>docker exec -it unity_benchmark bash</pre>
  2. Enter the Rails console <pre>bin/rails c [RAILS_ENV of running container]</pre>
  3. Instantiate the FireCloudClient <pre>client = FireCloudClient.new</pre>
  4. Open and parse the sample FireCloud profile template <pre>profile = JSON.parse(File.open(Rails.root.join('lib', 'assets', 'firecloud_profile_template.json')).read)</pre>
  5. Enter your desired values for every entry in the profile.
  6. Once the profile is completed, send your registration to the server <pre>client.set_profile(profile)</pre>
  
## RUNNING THE CONTAINER

Once the image has successfully built and the database container is running, use the following command to start the container:
<pre>bin/boot_docker -u (sendgrid username) -P (sendgrid password) -E (encryption key) -k (service account key path) -K (gcs admin service account key path) -o (oauth client id) -S (oauth client secret) -l</pre>

This sets up several environment variables in your shell and then runs the following command:
<pre>docker run --rm -it --name $CONTAINER_NAME --link $DATABASE_HOST:$DATABASE_HOST -p 80:80 -p 443:443 -h localhost -v $PROJECT_DIR:/home/app/webapp:rw -e PASSENGER_APP_ENV=$PASSENGER_APP_ENV -e DATABASE_HOST=$DATABASE_HOST -e DATABASE_USER=$DATABASE_USER -e ENCRYPTION_KEY=$ENCRYPTION_KEY -e PROD_DATABASE_PASSWORD=$DATABASE_PASSWORD -e SERVICE_ACCOUNT_KEY=$SERVICE_ACCOUNT_KEY -e SENDGRID_USERNAME=$SENDGRID_USERNAME -e SENDGRID_PASSWORD=$SENDGRID_PASSWORD -e SECRET_KEY_BASE=$SECRET_KEY_BASE -e OAUTH_CLIENT_ID=$OAUTH_CLIENT_ID -e OAUTH_CLIENT_SECRET=$OAUTH_CLIENT_SECRET -e GOOGLE_CLOUD_KEYFILE_JSON="$GOOGLE_CLOUD_KEYFILE_JSON" -e GOOGLE_PRIVATE_KEY="$GOOGLE_PRIVATE_KEY" -e GOOGLE_CLIENT_EMAIL="$GOOGLE_CLIENT_EMAIL" -e GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID" -e GOOGLE_CLOUD_PROJECT="$GOOGLE_CLOUD_PROJECT" unity_benchmark_docker:$DOCKER_IMAGE_VERSION</pre>

The container will then start running, and will execute its local startup scripts that will configure the application automatically.
You can then access your instance of Unity at https://localhost

You can also run the <code>bin/boot_docker</code> script in help mode by passing <code>-H</code> to print the help text
which will show you how to pass specific values to the above env variables.  <em>Note: running the shortcut script with
an environment of 'production' will cause the container to spawn headlessly by passing the <code>-d</code> flag, rather
than <code>--rm -it</code>.</em>

### DOCKER RUN COMMAND ENVIRONMENT VARIABLES
There are several variables that need to be passed to the Docker container in order to run properly:
1. *CONTAINER_NAME* (passed with --name): This names your container to whatever you want.  This is useful when linking containers.
1. *PROJECT_DIR* (passed with -v): This mounts your local working directory inside the Docker container.  Makes doing local development via hot deployment possible.
1. *PASSENGER_APP_ENV* (passed with -e): The Rails environment you wish to load.  Can be either development, test, or production (default is development).
1. *ENCRYPTION_KEY* (passed with -e): Salt value for encrypting sensitive information, like OAuth refresh tokens.  This must be at least 32 bytes in length, and cannot exceed 64 bytes.
1. *DATABASE_HOST* (passed with -e): Name of the container running postgres.  Even though our two containers are linked, this needs to be set to allow Rails to communicate with the database.
1. *DATABASE_USER* (passed with -e): Name of the container running postgres.  Even though our two containers are linked, this needs to be set to allow Rails to communicate with the database.
1. *DATABASE_PASSWORD* (passed with -e): Name of the container running postgres.  Even though our two containers are linked, this needs to be set to allow Rails to communicate with the database.
1. *SENDGRID_USERNAME* (passed with -e): The username associated with a Sendgrid account (for sending emails).
1. *SENDGRID_PASSWORD* (passed with -e): The password associated with a Sendgrid account (for sending emails).
1. *SECRET_KEY_BASE* (passed with -e): Sets the Rails SECRET_KEY_BASE environment variable, used mostly by Devise in authentication for cookies.
1. *SERVICE_ACCOUNT_KEY* (passed with -e): Sets the SERVICE_ACCOUNT_KEY environment variable, used for making authenticated API calls to FireCloud & GCP.
1. *GCS_ADMIN_GOOGLE_CLOUD_KEYFILE_JSON* (passed with -e): Sets the GCS_ADMIN_GOOGLE_CLOUD_KEYFILE_JSON environment variable, used for accessing user-controlled GCS assets.
1. *OAUTH_CLIENT_ID* (passed with -e): Sets the OAUTH_CLIENT_ID environment variable, used for Google OAuth2 integration.
1. *OAUTH_CLIENT_SECRET* (passed with -e): Sets the OAUTH_CLIENT_SECRET environment variable, used for Google OAuth2 integration.
1. *GOOGLE_[VARIOUS]* (passed with -e): If no SERVICE_ACCOUNT_KEY is present, the application will default to using the standard OAuth2 enviroment variables for authentication.  See [here](https://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-storage/v0.23.2/guides/authentication) for more information.
1. *DOCKER_IMAGE_VERSION*: sets the version of the unity_benchmark_docker image to use (defaults to _latest_)

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
* <b>-e ENCRYPTION_KEY= [ENCRYPTION_KEY]:</b> Salt value for encrypting sensitive information, like OAuth refresh tokens.  This value must be consistent, and between 32-64 bytes, or previously stored credentials will not decrypt correctly.
* <b>-e DATABASE_HOST= [DATABASE_HOST]:</b> Name of the container running postgres.  Even though our two containers are linked, this needs to be set to allow Rails to communicate with the database.
* <b>-e DATABASE_USER= [DATABASE_USER] -e DATABASE_PASSWORD= [DATABASE_PASSWORD]:</b> Credentials for authenticating into postgres.
* <b>-e SENDGRID_USERNAME= [SENDGRID_USERNAME] -e SENDGRID_PASSWORD= [SENDGRID_PASSWORD]:</b> The credentials for Sendgrid to send emails.  Alternatively, you could decide to not use Sendgrid and configure the application to use a different SMTP server (would be done inside your environment's config file).
* <b>-e SECRET_KEY_BASE= [SECRET_KEY_BASE]:</b> Setting the SECRET_KEY_BASE variable is necessary for creating secure cookies for authentication.  This variable automatically resets every time we restart the container.
* <b>-e SERVICE_ACCOUNT_KEY= [SERVICE_ACCOUNT_KEY]:</b> Setting the SERVICE_ACCOUNT_KEY variable is necessary for making authenticated API calls to FireCloud and GCP.  This should be a file path <b>relative to the app root</b> that points to the JSON service account key file you exported from GCP.
* <b>-e GCS_ADMIN_SERVICE_ACCOUNT_KEY= [GCS_ADMIN_SERVICE_ACCOUNT_KEY]:</b> Setting the GCS_ADMIN_SERVICE_ACCOUNT_KEY variable is necessary for accessing resources in GCP in user-controlled workspaces.  This service account is added with WRITER permissions to all Unity-associated workspaces.
* <b>-e OAUTH_CLIENT_ID= [OAUTH_CLIENT_ID] -e OAUTH_CLIENT_SECRET= [OAUTH_CLIENT_SECRET]:</b> Setting the OAUTH_CLIENT_ID and OAUTH_CLIENT_SECRET variables are necessary for allowing Google user authentication.  For instructions on creating OAuth 2.0 Client IDs, refer to the [Google OAuth 2.0 documentation](https://support.google.com/cloud/answer/6158849).
* *unity_benchmark_docker*: This is the name of the image we created earlier.  If you chose a different name, please use that here.
* *$DOCKER_IMAGE_VERSION*: Version number of the above Docker image.

## TESTS

### UNIT & INTEGRATION
To run all available rake tests (unit & integration), simply boot the container in test mode:
<pre>bin/boot_docker -e test -E (encryption key) -u (sendgrid username) -P (sendgrid password) -k (service account key path) -K (gcs admin service account key path) -o (oauth client id) -S (oauth client secret) -l</pre>

## PRODUCTION DEPLOYMENT

### KUBERNETES

Unity is designed to be deployed via [Kubernetes](https://kubernetes.io), although this is not the only way that Unity can be deployed (see below for details). 
To deploy Unity in Kubernetes, you will need the following prerequisites:
* A Kubernetes cluster already [created](https://cloud.google.com/kubernetes-engine/docs/quickstart#create_cluster) in your GCP project
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) installed
* Set your local kubernetes config to [point at your remote cluster](https://cloud.google.com/sdk/gcloud/reference/container/clusters/get-credentials):
  * <code>gcloud container clusters get-credentials NAME -z ZONE</code>

Unity is also pre-configured to leverage Cloud SQL when deployed to a Kubernetes cluster.  To configure this:
1. Log into your GCP Project and select 'SQL' from the left-hand hamburger menu
1. Select 'Create an instance'
1. Select 'PostgreSQL' and click 'Next'
1. Give the instance a name, a default user password, select a region, and click 'Create'
1. Once your instance has created, click on its name to load the instance details
1. Copy the instance connection name, and paste it into the line beginning with <code>"-instances="</code> under the cloudsql-proxy container 
details in <code>config/unity-benchmark-deployment.yaml</code>

You will then need to create a service account with the <code>Cloud SQL Client</code> role to be used to connect to the instance.

Before creating your deployment (but after your cluster is created), you will need to create the necessary secrets in Kubernetes to load 
into your deployment.  These secrets must be created with the following key/value pairs:

1. cloudsql-db-credentials
   1. username: database username
   1. password: database password
1. oauth-client-credentials
   1. client_id: OAuth client ID
   1. client_secret: OAuth client secret
1. encryption-key
   1. encryption-key: 32-byte encryption key string
1. unity-service-account
   1. unity-benchmark-service-account.json: JSON contents of Unity project service account credentials (must be project owner/editor)
1. unity-gcs-admin-service-account
   1. unity-benchmark-gcs-admin.json: JSON contents of Unity GCS Admin service account credentials (must be have Google Cloud Storage Admin role)
1. cloudsql-instance-credentials
   1. credentials.json: JSON contents of CloudSQL service account credentials (must have Cloud SQL Client role)
1. google-site-verification
   1. verification-code: google-site-verification meta header value (for verifying site ownership in Google search console, required for OAuth verification)
1. ssl-certificate
   1. localhost.crt: a valid SSL certificate for your domain (filename of localhost does not affect certificate)
1. ssl-keyfile
   1. localhost.key: keyfile for your SSL certificate (filename of localhost does not affect certificate)
1. prod-secret-key-base
   1. secret-key-base: value for SECRET_KEY_BASE, which is used to encrypt secure cookies.  This can be set/updated by using <code>bin/set_prod_secret_key_base</code>
1. sendgrid-credentials
	 1. username: Username for your Sendgrid account
	 1. password: Password for your Sendgrid account

See [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/) for more information on how to import and save secrets.

Once your secrets are loaded and <code>kubectl</code> is pointing at your remote cluster:
1. Navigate to the project directory
1. Create the deployment: <code>kubectl apply -f config/unity-benchmark-deployment.yaml</code>
1. Create the service: <code>kubectl apply -f config/unity-benchmark-service.yaml</code>
1. Once your service is running, get the EXTERNAL-IP address: <code>kubectl get service unity-benchmark-service</code>
1. You can change the external IP from ephemeral to static inside your VPC Network > [External IP Addresses](https://console.cloud.google.com/networking/addresses/list) console in GCP

Unity will now be available publicly on the above IP address.

TODO: Update deployment to load CloudSQL instance connection details from environment variables

#### PATCHING DEPLOYMENTS

If an update does not require incrementing a Docker image version number, you can force a restart by calling <code>bin/patch_deployment</code>.
This will 'patch' the current deployment by updating an annotation on the deployment (specifically, the date) and force 
a full restart, including a <code>docker pull</code>.

NOTE: You must push an update to your docker image first via <code>docker push</code>.

### OTHER DEPLOYMENTS

Unity can also be deployed on any infrastructure that will support [Docker](https://www.docker.com).  This could be on 
Google Cloud Platform, Amazon Web Services, or any other provider/operating system where Docker can be installed.  For instructions 
on how to deploy, provision a virtual machine, install Docker, and then follow the instructions for 'RUNNING THE CONTAINER', 
with the difference of adding <code>-e production</code> to <code>bin/boot_docker</code>.

The Unity database can be deployed either as a linked docker container (as in development, see 'BEFORE RUNNING THE CONTAINER IN DEVELOPMENT' 
for more info, then linked by passing <code>-l</code> to <code>bin/boot_docker</code>) or a as a separate host, via <code>-m [DATABASE HOST]</code>.  

### FIRECLOUD INTEGRATION

The Unity Benchmark Service utilizes [FireCloud](https://software.broadinstitute.org/firecloud/) for storing data and launching workflow
submissions, which in turn store raw files in GCP buckets.  This is all managed through a GCP service account which in turn owns all workspaces
and manages them on behalf of users.  This is why your service account must be registered as a FireCloud user before the service 
can function correctly.

### OAUTH VERIFICATION

Once you obtain a URL and a valid SSL certificate, you may go ahead and have your application verified for OAuth to remove 
unverified application warnings.  Please refer to [this form](https://https://support.google.com/code/contact/oauth_app_verification) 
for more information on the OAuth verification process.  You must also generate a separate OAuth client to use in production 
that does not contain localhost URLs, as this will cause your request to be rejected.

The following scopes must be provided as part of the verification process (with the following justifications):

* https://www.googleapis.com/auth/userinfo.profile (to allow users to authenticate using their Google account)
* https://www.googleapis.com/auth/userinfo.email (to allow users to authenticate using their Google account)
* https://www.googleapis.com/auth/cloud-billing.readonly (to allow Unity to see available billing accounts to create projects on behalf of users)
* https://www.googleapis.com/auth/cloud-platform.read-only (to allow Unity to stream user-owned GCS objects back to the client)