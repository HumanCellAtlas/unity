##
# FireCloudClient: Class that wraps API calls to both FireCloud and Google Cloud Storage to manage the CRUDing of both
# FireCloud workspaces and files inside the associated GCP storage buckets, as well as billing/user group/workflow submission
# management.
#
# Uses the gems googleauth (for generating access tokens), google-cloud-storage (for bucket/file access),
# and rest-client (for HTTP calls)
#
# Author::  Jon Bistline  (mailto:bistline@broadinstitute.org)

class FireCloudClient < Struct.new(:user, :project, :access_token, :api_root, :storage, :expires_at)

	#
  # CONSTANTS
  #

	# base url for all API calls
	BASE_URL = 'https://api.firecloud.org'
	# default auth scopes
	GOOGLE_SCOPES = %w(https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/cloud-billing.readonly https://www.googleapis.com/auth/cloud-platform.read-only)
	# constant used for retry loops in process_firecloud_request and execute_gcloud_method
	MAX_RETRY_COUNT = 3
	# default namespace used for all FireCloud workspaces owned by the 'portal'
	PORTAL_NAMESPACE = 'single-cell-portal'
	# location of Google service account JSON (must be absolute path to file)
	SERVICE_ACCOUNT_KEY = !ENV['SERVICE_ACCOUNT_KEY'].blank? ? File.absolute_path(ENV['SERVICE_ACCOUNT_KEY']) : ''
	# Permission values allowed for FireCloud workspace ACLs
	WORKSPACE_PERMISSIONS = ['OWNER', 'READER', 'WRITER', 'NO ACCESS']
  # List of FireCloud user group roles
  USER_GROUP_ROLES = %w(admin member)
	# List of FireCloud billing project roles
	BILLING_PROJECT_ROLES = %w(user owner)
  # List of available FireCloud 'operations' for updating FireCloud workspace entities or attributes
  AVAILABLE_OPS = %w(AddUpdateAttribute RemoveAttribute AddListMember RemoveListMember)
  # List of projects where computes are not permitted (sets canCompute to false for all users by default, can only be overridden
  # by PROJECT_OWNER)
  COMPUTE_BLACKLIST = %w(single-cell-portal)

  # initialize is called after instantiating with FireCloudClient.new
	# will set the access token, FireCloud api url root and GCP storage driver instance
	#
  # * *params*
  #   - +user+: (User) => User object from which access tokens are generated
  #   - +project+: (String) => Default GCP Project to use (can be overridden by other parameters)
  # * *return*
  #   - +FireCloudClient+ object
	def initialize(user=nil, project=nil)
		# when initializing without a user, default to base configuration
		if user.nil?
			self.access_token = FireCloudClient.generate_access_token
			self.project = PORTAL_NAMESPACE

			# instantiate Google Cloud Storage driver to work with files in workspace buckets
			# if no keyfile is present, use environment variables
			storage_attr = {
					project: PORTAL_NAMESPACE,
					timeout: 3600
			}
			if !ENV['SERVICE_ACCOUNT_KEY'].blank?
				storage_attr.merge!(keyfile: SERVICE_ACCOUNT_KEY)
			end

			self.storage = Google::Cloud::Storage.new(storage_attr)

			# set expiration date of token
			self.expires_at = Time.now + self.access_token['expires_in']
		else
			self.user = user
			self.project = project
			# when initializing with a user, pull access token from user object and set desired project
			self.access_token = user.valid_access_token
			self.expires_at = self.access_token['expires_at']

			# use user-defined project instead of portal default
			# if no keyfile is present, use environment variables
			storage_attr = {
					project: project,
					timeout: 3600
			}
			if !ENV['SERVICE_ACCOUNT_KEY'].blank?
				storage_attr.merge!(keyfile: SERVICE_ACCOUNT_KEY)
			end

			self.storage = Google::Cloud::Storage.new(storage_attr)
		end

		# set FireCloud API base url
		self.api_root = BASE_URL
	end

	#
	# TOKEN METHODS
	#

	# generate an access token to use for all requests
	#
	# * *return*
	#   - +Hash+ of Google Auth access token (contains access_token (string), token_type (string) and expires_in (integer, in seconds)
	def self.generate_access_token
		# if no keyfile present, use environment variables
		creds_attr = {scope: GOOGLE_SCOPES}
		if !ENV['SERVICE_ACCOUNT_KEY'].blank?
			creds_attr.merge!(json_key_io: File.open(SERVICE_ACCOUNT_KEY))
		end
		creds = Google::Auth::ServiceAccountCredentials.make_creds(creds_attr)
		token = creds.fetch_access_token!
		token
	end

	# refresh access_token when expired and stores back in FireCloudClient instance
	#
	# * *return*
	#   - +DateTime+ timestamp of new access token expiration
	def refresh_access_token
		if self.user.nil?
			new_token = FireCloudClient.generate_access_token
			new_expiry = Time.now + new_token['expires_in']
			self.access_token = new_token
			self.expires_at = new_expiry
		else
			new_token = self.user.generate_access_token
			self.access_token = new_token
			self.expires_at = new_token['expires_at']
		end
		self.expires_at
	end

	# check if an access_token is expired
	#
	# * *return*
	#   - +Boolean+ of token expiration
	def access_token_expired?
		Time.now >= self.expires_at
	end

	##
	## STORAGE INSTANCE METHODS
	##

  # get instance information about the storage driver
  #
	# * *return*
	#   - +JSON+ object of storage driver instance attributes
  def storage_attributes
		JSON.parse self.storage.to_json
	end

  # renew the storage driver
	#
	# * *params*
  #   - +project_name+ (String )=> name of GCP project, default project is value of PORTAL_NAMESPACE
  #
	# * *return*
	#   - +Google::Cloud::Storage+ instance
  def refresh_storage_driver(project_name=PORTAL_NAMESPACE)
		storage_attr = {
				project: project_name,
				timeout: 3600
		}
		if !ENV['SERVICE_ACCOUNT_KEY'].blank?
			storage_attr.merge!(keyfile: SERVICE_ACCOUNT_KEY)
		end
		new_storage = Google::Cloud::Storage.new(storage_attr)
		self.storage = new_storage
		new_storage
	end

  # get storage driver access token
  #
	# * *return*
	#   - +String+ access token
  def storage_access_token
		self.storage.service.credentials.client.access_token
	end

  # get storage driver issue timestamp
  #
	# * *return*
	#   - +DateTime+ issue timestamp
  def storage_issued_at
		self.storage.service.credentials.client.issued_at
	end

  # get issuer of storage credentials
  #
	# * *return*
	#   - +String+ of issuer email
  def storage_issuer
		self.storage.service.credentials.issuer
	end

  # get issuer of access_token
  #
	# * *return*
	#   - +String+ of access_token issuer email
  def issuer
		self.user.nil? ? self.storage_issuer : self.user.email
	end

	######
	##
	## FIRECLOUD METHODS
	##
	######

	# generic handler to execute http calls, process returned JSON and handle exceptions
	#
	# * *params*
	#   - +http_method+ (String, Symbol) => valid http method
	#   - +path+ (String) => FireCloud REST API path
	#   - +payload+ (Hash) => HTTP POST/PATCH/PUT body for creates/updates, defaults to nil
	#		- +opts+ (Hash) => Hash of extra options (defaults are file_upload=false, max_attemps=MAX_RETRY_COUNT)
	#
	# * *return*
	#   - +Hash+, +Boolean+ depending on response body
	# * *raises*
	#   - +RuntimeError+
	def process_firecloud_request(http_method, path, payload=nil, opts={})
		# set up default options
		request_opts = {file_upload: false, max_attempts: MAX_RETRY_COUNT}.merge(opts)

		# check for token expiry first before executing
		if self.access_token_expired?
			Rails.logger.info "#{Time.now}: FireCloudClient token expired, refreshing access token"
			self.refresh_access_token
		end
		# set default headers
		headers = {
				'Authorization' => "Bearer #{self.access_token['access_token']}"
		}
		# if not uploading a file, set the content_type to application/json
		if !request_opts[:file_upload]
			headers.merge!({'Content-Type' => 'application/json'})
		end

		# initialize counter to prevent endless feedback loop
		@retry_count ||= 0

		# process request
		if @retry_count < request_opts[:max_attempts]
			begin
				@retry_count += 1
				@obj = RestClient::Request.execute(method: http_method, url: path, payload: payload, headers: headers)
				# handle response codes as necessary
				if ok?(@obj.code) && !@obj.body.blank?
					@retry_count = 0
					begin
						return JSON.parse(@obj.body)
					rescue JSON::ParserError => e
						return @obj.body
					end
				elsif ok?(@obj.code) && @obj.body.blank?
					@retry_count = 0
					return true
				else
					Rails.logger.info "#{Time.now}: Unexpected response #{@obj.code}, not sure what to do here..."
					@obj.message
				end
			rescue RestClient::Exception => e
				context = " encountered when requesting '#{path}'"
				log_message = "#{Time.now}: " + e.message + context
				Rails.logger.error log_message
				@error = e
				process_firecloud_request(http_method, path, payload, opts)
			end
		else
			@retry_count = 0
			error_message = parse_error_message(@error)
			Rails.logger.error "#{Time.now}: Retry count exceeded - #{error_message}"
			raise RuntimeError.new(error_message)
		end
	end

	##
	## API STATUS
	##

	# determine if FireCloud api is currently up/available
	#
	# * *return*
	#   - +Boolean+ indication of FireCloud current status
	def api_available?
		begin
			response = self.api_status
			if response.is_a?(Hash) && response['ok']
				true
			else
				false
			end
		rescue => e
			false
		end
  end

  # get more detailed status information about FireCloud api
  # this method doesn't use process_firecloud_request as we want to preserve error states rather than catch and suppress them
  #
	# * *return*
	#   - +Hash+ with health status information for various FireCloud services or error response
  def api_status
    path = self.api_root + '/status'
    # make sure access token is still valid
    self.access_token_expired? ? self.refresh_access_token : nil
    headers = {
        'Authorization' => "Bearer #{self.access_token['access_token']}",
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
    }
    begin
      response = RestClient::Request.execute(method: :get, url: path, headers: headers)
      JSON.parse(response.body)
    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.error "#{Time.now}: FireCloud status error: #{e.message}"
      e.response
    end
  end

	##
	## WORKSPACE METHODS
	##

	# return a list of all workspaces in a given namespace
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#
	# * *return*
	#   - +Array+ of +Hash+ objects detailing workspaces
	def workspaces(workspace_namespace)
		path = self.api_root + '/api/workspaces'
		workspaces = process_firecloud_request(:get, path)
		workspaces.keep_if {|ws| ws['workspace']['namespace'] == workspace_namespace}
	end

	# create a workspace, prepending WORKSPACE_NAME_PREFIX as necessary
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of workspace
	#
  # * *return*
  #   - +Hash+ object of workspace instance
	def create_workspace(workspace_namespace, workspace_name, *authorization_domains)
		path = self.api_root + '/api/workspaces'
		# construct payload for POST
		payload = {
				namespace: workspace_namespace,
				name: workspace_name,
				attributes: {},
				authorizationDomain: []
		}
		# add authorization domains to new workspace
		authorization_domains.each do |domain|
			payload[:authorizationDomain] << {membersGroupName: domain}
		end
		process_firecloud_request(:post, path, payload.to_json)
	end

	# get the specified workspace
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of workspace
	#
  # * *return*
  #   - +Hash+ object of workspace instance
	def get_workspace(workspace_namespace, workspace_name)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}"
		process_firecloud_request(:get, path)
	end

	# delete a workspace
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of workspace
	#
  # * *return*
  #   - +Hash+ message of status of workspace deletion
	def delete_workspace(workspace_namespace, workspace_name)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}"
		process_firecloud_request(:delete, path)
	end

	# get the specified workspace ACL
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of workspace
	#
  # * *return*
  #   - +Hash+ object of workspace ACL instance
	def get_workspace_acl(workspace_namespace, workspace_name)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/acl"
		process_firecloud_request(:get, path)
	end

	# update the specified workspace ACL
	# can also be used to remove access by passing 'NO ACCESS' to create_acl
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of workspace
	#   - +acl+ (JSON) => ACL object (see create_workspace_acl)
	#
  # * *return*
  #   - +Hash+ response of ACL update
	def update_workspace_acl(workspace_namespace, workspace_name, acl)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/acl?inviteUsersNotFound=true"
		process_firecloud_request(:patch, path, acl)
	end

	# helper for creating FireCloud ACL objects
	# will raise a RuntimeError if permission requested does not match allowed values in WORKSPACE_PERMISSONS
	#
	# * *params*
	#   - +email+ (String) => email of FireCloud user
	#   - +permission+ (String) => granted permission level
	#   - +share_permission+ (Boolean) => whether or not user can share workspace
	#   - +compute_permission+ (Boolean) => whether or not user can run computes in workspace
	#
  # * *return*
  #   - +JSON+ ACL object
	def create_workspace_acl(email, permission, share_permission=true, compute_permission=false)
		if WORKSPACE_PERMISSIONS.include?(permission)
			[
					{
							'email' => email,
							'accessLevel' => permission,
							'canShare' => share_permission,
							'canCompute' => compute_permission
					}
			].to_json
		else
			raise RuntimeError.new("Invalid FireCloud ACL permission setting: #{permission}; must be member of #{WORKSPACE_PERMISSIONS.join(', ')}")
		end
	end

	# set attributes for the specified workspace (will delete all existing attributes and overwrite with provided info)
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of workspace
	#   - +attributes+ (Hash) => Hash of workspace attributes (description, tags (Array), key/value pairs of other attributes)
	#
  # * *return*
  #   - +Hash+ object of workspace
	def set_workspace_attributes(workspace_namespace, workspace_name, attributes)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/setAttributes"
		process_firecloud_request(:patch, path, attributes.to_json)
	end

	# get the current storage cost estimate for a workspace
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of workspace
	#
  # * *return*
  #   - +Hash+ object of workspace
	def get_workspace_storage_cost(workspace_namespace, workspace_name)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/storageCostEstimate"
		process_firecloud_request(:get, path)
	end

  ##
  ## WORKFLOW SUBMISSION METHODS
	##

  # get list of available FireCloud methods
  #
	# * *params*
	#   - +opts+ (Hash) => hash of query parameter key/value pairs, see https://api.firecloud.org/#!/Method_Repository/listMethodRepositoryMethods for complete list
  #
  # * *return*
  #   - +Array+ of methods
  def get_methods(opts={})
		query_params = self.merge_query_options(opts)
		path = self.api_root + "/api/methods#{query_params}"
		process_firecloud_request(:get, path)
	end

	# get a FireCloud method object
	#
	# * *params*
	#   - +namespace+ (String) => namespace of method
	#   - +name+ (String) => name of method
	#   - +snapshot_id+ (Integer) => snapshot ID of method
	#   - +only_payload+ (Boolean) => boolean of whether or not to return only the payload object
  #
  # * *return*
  #   - +Hash+ method object
	def get_method(namespace, method_name, snapshot_id, only_payload=false)
		path = self.api_root + "/api/methods/#{namespace}/#{method_name}/#{snapshot_id}?onlyPayload=#{only_payload}"
		process_firecloud_request(:get, path)
	end

	# get list of available configurations from the repository
	#
	# * *params*
	#   - +opts+ (Hash) => hash of query parameter key/value pairs, see https://api.firecloud.org/#!/Method_Repository/listMethodRepositoryConfigurations for complete list
	#
  # * *return*
  #   - +Array+ of configurations
	def get_configurations(opts={})
		query_params = self.merge_query_options(opts)
		path = self.api_root + "/api/configurations#{query_params}"
		process_firecloud_request(:get, path)
	end

	# get a FireCloud method configuration from the repository
	#
	# * *params*
	#   - +namespace+ (String) => namespace of method
	#   - +name+ (String) => name of configuration
	#   - +snapshot_id+ (Integer) => snapshot ID of method
	#   - +payload_as_object+ (Boolean) => Instead of returning a string under key payload, return a JSON object under key payloadObject
	#
  # * *return*
  #   - +Hash+ configuration object
	def get_configuration(namespace, name, snapshot_id, payload_as_object=false)
		path = self.api_root + "/api/configurations/#{namespace}/#{name}/#{snapshot_id}?payloadAsObject=#{payload_as_object}"
		process_firecloud_request(:get, path)
	end

	# copy a FireCloud method configuration from the repository into a workspace
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of workspace
	#   - +config_namespace+ (String) => namespace of source configuration
	#   - +config_name+ (String) => name of source configuration
	#   - +snapshot_id+ (Integer) => snapshot ID of source configuration
	#   - +destination_namespace+ (String) => namespace of destination configuration (in workspace)
	#   - +destination_name+ (String) => name of destination configuration (in workspace)
	#
  # * *return*
  #   - +Hash+ configuration object
	def copy_configuration_to_workspace(workspace_namespace, workspace_name, config_namespace, config_name, snapshot_id, destination_namespace, destination_name)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/method_configs/copyFromMethodRepo"
		payload = {
				configurationNamespace: config_namespace,
				configurationName: config_name,
				configurationSnapshotId: snapshot_id,
				destinationNamespace: destination_namespace,
				destinationName: destination_name
		}.to_json
		process_firecloud_request(:post, path, payload)
	end

  # create a method configuration template from a method
  #
	# * *params*
	#   - +method_namespace+ (String) => namespace of method
	#   - +method_name+ (String) => name of method
	#   - +method_version+ (String) => version of method
  #
  # * *return*
  #   - +Hash+ method configuration template
	def create_configuration_template(method_namespace, method_name, method_version)
		path = self.api_root + '/api/template'
		payload = {
				methodNamespace: method_namespace,
				methodName: method_name,
				methodVersion: method_version
		}.to_json
		process_firecloud_request(:post, path, payload)
	end

	# get a list of FireCloud method configurations in a specified workspace
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of requested workspace
	#
  # * *return*
  #   - +Array+ of configuration objects
  def get_workspace_configurations(workspace_namespace, workspace_name)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/methodconfigs"
		process_firecloud_request(:get, path)
	end

	# get a FireCloud method configuration from a workspace
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of requested workspace
	#   - +config_namespace+ (String) => namespace of configuration
	#   - +config_name+ (String) => name of configuration
	#
	# * *return*
	#   - +Hash+ configuration object
	def get_workspace_configuration(workspace_namespace, workspace_name, config_namespace, config_name)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/method_configs/#{config_namespace}/#{config_name}"
		process_firecloud_request(:get, path)
	end

	# create a FireCloud method configuration in a workspace from a template or existing configuration
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of requested workspace
	#		- +configuration+ (Hash) => configuration object (see https://api.firecloud.org/#!/Method_Configurations/updateWorkspaceMethodConfig for more info)
	#
	# * *return*
	#   - +Hash+ configuration object
	def create_workspace_configuration(workspace_namespace, workspace_name, configuration)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/methodconfigs"
		process_firecloud_request(:post, path, configuration.to_json)
	end

	# update a FireCloud method configuration in a workspace
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of requested workspace
	#   - +config_namespace+ (String) => namespace of configuration
	#   - +config_name+ (String) => name of configuration
	#		- +configuration+ (Hash) => configuration object (see https://api.firecloud.org/#!/Method_Configurations/updateWorkspaceMethodConfig for more info)
	#
	# * *return*
	#   - +Hash+ configuration object
	def update_workspace_configuration(workspace_namespace, workspace_name, config_namespace, config_name, configuration)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/method_configs/#{config_namespace}/#{config_name}"
		process_firecloud_request(:post, path, configuration.to_json)
	end

	# overwrite an existing FireCloud method configuration in a workspace
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of requested workspace
	#   - +config_namespace+ (String) => namespace of configuration
	#   - +config_name+ (String) => name of configuration
	#		- +configuration+ (Hash) => configuration object (see https://api.firecloud.org/#!/Method_Configurations/overwriteWorkspaceMethodConfig for more info)
	#
	# * *return*
	#   - +Hash+ configuration object
	def overwrite_workspace_configuration(workspace_namespace, workspace_name, config_namespace, config_name, configuration)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/method_configs/#{config_namespace}/#{config_name}"
		process_firecloud_request(:put, path, configuration.to_json)
	end

  # get submission queue status
  #
  # * *return*
  #   - +Hash+ object of current submission queue status
	def get_submission_queue_status
		path = self.api_root + '/api/submissions/queueStatus'
		process_firecloud_request(:get, path)
	end

  # get a list of workspace workflow queue submissions
  #
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of requested workspace
  #
  # * *return*
  #   - +Array+ of workflow submissions
  def get_workspace_submissions(workspace_namespace, workspace_name)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/submissions"
		process_firecloud_request(:get, path)
	end

	# validate a workflow submission before submitting
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of requested workspace
	#   - +config_namespace+ (String) => namespace of requested configuration
	#   - +config_name+ (String) => name of requested configuration
	#   - +entity_type+ (String) => type of workspace entity (e.g. sample, participant, etc)
	#   - +entity_name+ (String) => name of workspace entity
	#
	# * *return*
	#   - +Hash+ of workflow submission details
	def validate_workspace_submission(workspace_namespace, workspace_name, config_namespace, config_name, entity_type, entity_name)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/submissions/validate"
		submission = {
				methodConfigurationNamespace: config_namespace,
				methodConfigurationName: config_name,
				entityType: entity_type,
				entityName: entity_name,
				useCallCache: true,
				workflowFailureMode: 'NoNewCalls'
		}.to_json

		process_firecloud_request(:post, path, submission)
	end

	# create a workflow submission
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of requested workspace
	#   - +config_namespace+ (String) => namespace of requested configuration
	#   - +config_name+ (String) => name of requested configuration
	#   - +entity_type+ (String) => type of workspace entity (e.g. sample, participant, etc)
	#   - +entity_name+ (String) => name of workspace entity
	#
  # * *return*
  #   - +Hash+ of workflow submission details
	def create_workspace_submission(workspace_namespace, workspace_name, config_namespace, config_name, entity_type, entity_name)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/submissions"
		submission = {
				methodConfigurationNamespace: config_namespace,
				methodConfigurationName: config_name,
				entityType: entity_type,
				entityName: entity_name,
				useCallCache: true,
				workflowFailureMode: 'NoNewCalls'
		}.to_json
		process_firecloud_request(:post, path, submission)
	end

	# get a single workflow submission
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of requested workspace
	#   - +submission_id+ (String) => id of requested submission
	#
  # * *return*
  #   - +Hash+ workflow submission object
	def get_workspace_submission(workspace_namespace, workspace_name, submission_id)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/submissions/#{submission_id}"
		process_firecloud_request(:get, path)
	end

	# abort a workflow submission
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of requested workspace
	#   - +submission_id+ (Integer) => ID of workflow submission
	#
  # * *return*
  #   - +Boolean+ indication of workflow cancellation
	def abort_workspace_submission(workspace_namespace, workspace_name, submission_id)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/submissions/#{submission_id}"
		process_firecloud_request(:delete, path)
	end

	# get call-level metadata from a single workflow submission workflow instance
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of requested workspace
	#   - +submission_id+ (String) => id of requested submission
	#   - +workflow_id+ (String) => id of requested workflow
	#
  # * *return*
  #   - +Hash+ of workflow object
	def get_workspace_submission_workflow(workspace_namespace, workspace_name, submission_id, workflow_id)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/submissions/#{submission_id}/workflows/#{workflow_id}"
		process_firecloud_request(:get, path)
	end

	# get outputs from a single workflow submission workflow instance
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of requested workspace
	#   - +submission_id+ (String) => id of requested submission
	#   - +workflow_id+ (String) => id of requested workflow
	#
  # * *return*
  #   - +Array+ of workflow submission outputs
	def get_workspace_submission_outputs(workspace_namespace, workspace_name, submission_id, workflow_id)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/submissions/#{submission_id}/workflows/#{workflow_id}/outputs"
		process_firecloud_request(:get, path)
	end

	# get permissions for a method configuration namespace
	#
	# * *params*
	#   - +config_namespace+ (String) => namespace of configuraiton
	#
	# * *return*
	#   - +Array+ of users & permission levels
	def get_config_namespace_permissions(config_namespace)
		path = self.api_root + "/api/configurations/#{config_namespace}/permissions"
		process_firecloud_request(:get, path)
	end

	# get permissions for a method configuration namespace
	#
	# * *params*
	#   - +config_namespace+ (String) => namespace of configuraiton
	#   - +permissions+ (Array) => Array of permission objects (Hash of user & role)
	#
	# * *return*
	#   - +Array+ of users & permission levels
	def update_config_namespace_permissions(config_namespace, permissions)
		path = self.api_root + "/api/configurations/#{config_namespace}/permissions"
		process_firecloud_request(:post, path, permissions.to_json)
	end

	# get permissions for a method namespace
	#
	# * *params*
	#   - +config_namespace+ (String) => namespace of configuraiton
	#
	# * *return*
	#   - +Array+ of users & permission levels
	def get_method_namespace_permissions(config_namespace)
		path = self.api_root + "/api/methods/#{config_namespace}/permissions"
		process_firecloud_request(:get, path)
	end

	# get permissions for a method namespace
	#
	# * *params*
	#   - +config_namespace+ (String) => namespace of configuraiton
	#   - +permissions+ (Array) => Array of permission objects (Hash of user & role)
	#
	# * *return*
	#   - +Array+ of users & permission levels
	def update_method_namespace_permissions(config_namespace, permissions)
		path = self.api_root + "/api/methods/#{config_namespace}/permissions"
		process_firecloud_request(:post, path, permissions.to_json)
	end

	##
	## WORKSPACE ENTITY METHODS
	##

	# list workspace metadata entities with type and attribute information
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of requested workspace
	#
  # * *return*
  #   - +Array+ of workspace metadata entities with type and attribute information
	def get_workspace_entities(workspace_namespace, workspace_name)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/entities_with_type"
		process_firecloud_request(:get, path)
	end

	# list workspace metadata entity types
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of requested workspace
	#
  # * *return*
  #   - +Array+ of workspace metadata entities
	def get_workspace_entity_types(workspace_namespace, workspace_name)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/entities"
		process_firecloud_request(:get, path)
	end

	# get a list workspace metadata entities of requested type
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of requested workspace
	#   - +entity_type+ (String) => type of requested entity
	#
  # * *return*
  #   - +Array+ of workspace metadata entities with type and attribute information
	def get_workspace_entities_by_type(workspace_namespace, workspace_name, entity_type)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/entities/#{entity_type}"
		process_firecloud_request(:get, path)
	end

	# get an individual workspace metadata entity
	#
  # * *params*
  #   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of requested workspace
	#   - +entity_type+ (String) => type of requested entity
	#   - +entity_name+ (String) => name of requested entity
	#
  # * *return*
  #   - +Array+ of workspace metadata entities with type and attribute information
	def get_workspace_entity(workspace_namespace, workspace_name, entity_type, entity_name)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/entities/#{entity_type}/#{entity_name}"
		process_firecloud_request(:get, path)
	end

	# update an individual workspace metadata entity
	#
  # * *params*
  #   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of requested workspace
	#   - +entity_type+ (String) => type of requested entity
	#   - +entity_name+ (String) => name of requested entity
	#   - +operation_type+ (String) => type of operation requested (add/update)
	#   - +attribute_name+ (String) => name of attribute being changed
  #   - +attribute_value+ (String) => value of attribute being changed
	#
  # * *return*
  #   - +Array+ of workspace metadata entities with type and attribute information
	def update_workspace_entity(workspace_namespace, workspace_name, entity_type, entity_name, operation_type, attribute_name, attribute_value)
		update = {
				op: operation_type,
				attributeName: attribute_name,
				addUpdateAttribute: attribute_value
		}.to_json
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/entities/#{entity_type}/#{entity_name}"
		process_firecloud_request(:patch, path, update)
	end

	# get a tsv file of requested workspace metadata entities of requested type
	#
  # * *params*
  #   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of requested workspace
	#   - +entity_type+ (String) => type of requested entity
  #   - +entity_names+ (String) => list of requested entities to include in file (provide each as a separate parameter)
	#
  # * *return*
  #   - +Array+ of workspace metadata entities with type and attribute information
	def get_workspace_entities_as_tsv(workspace_namespace, workspace_name, entity_type, *attribute_names)
		attribute_list = attribute_names.join(',')
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/entities/#{entity_type}/tsv#{attribute_list.blank? ? nil : '?attributeNames=' + attribute_list}"
		process_firecloud_request(:get, path)
	end

	# get a tsv file of requested workspace metadata entities of requested type
	#
  # * *params*
  #   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of requested workspace
	#   - +entities_file+ (File) => valid TSV import file of metadata entities (must be an open File handler)
	#
  # * *return*
  #   -  String of entity type that was just created
	def import_workspace_entities_file(workspace_namespace, workspace_name, entities_file)
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/importEntities"
		entities_upload = {
				entities: entities_file
		}
		process_firecloud_request(:post, path, entities_upload, {file_upload: true})
	end

	# bulk delete workspace metadata entities
	#
  # * *params*
  #   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of requested workspace
  #   - +workspace_entities+ (Array of objects) => array of hashes mapping to workspace metadata entities
	#
  # * *return*
  #   - +Array+ of workspace metadata entities
	def delete_workspace_entities(workspace_namespace, workspace_name, workspace_entities)
		# validate entities first before making delete call
		valid_workspace_entities = []
		workspace_entities.each do |entity|
			if entity.keys.sort.map(&:to_s) == %w(entityName entityType) && entity.values.size == 2
				valid_workspace_entities << entity
			end
		end
		path = self.api_root + "/api/workspaces/#{workspace_namespace}/#{workspace_name}/entities/delete"
		process_firecloud_request(:post, path,  valid_workspace_entities.to_json)
	end

  ##
  ## USER GROUPS METHODS (only work when FireCloudClient is instantiated with a User account)
  ##

  # get a list of groups for a user
  #
  # * *return*
  #   - +Array+ of groups
  def get_user_groups
		path = self.api_root + "/api/groups"
		process_firecloud_request(:get, path)
	end

	# get a specific user group that the user belongs to
	#
  # * *params*
  #   - +group_name+ (String) => name of requested group
  #
  # * *return*
  #   - +Hash+ of group attributes
	def get_user_group(group_name)
		path = self.api_root + "/api/groups/#{group_name}"
		process_firecloud_request(:get, path)
	end

	# create a user group
	#
  # * *params*
  #   - +group_name+ (String) => name of requested group
	#
  # * *return*
  #   - +Hash+ of group attributes
	def create_user_group(group_name)
		path = self.api_root + "/api/groups/#{group_name}"
		process_firecloud_request(:post, path)
	end

	# delete a user group that a user owns
	#
  # * *params*
  #   - +group_name+ (String) => name of requested group
	#
  # * *return*
  #   - +Boolean+ indication of group delete
	def delete_user_group(group_name)
		path = self.api_root + "/api/groups/#{group_name}"
		process_firecloud_request(:delete, path)
	end

	# add another user to a user group the current user owns
	#
  # * *params*
  #   - +group_name+ (String) => name of requested group
	#   - +user_role+ (String) => role of user to add to group (must be member or admin)
	#   - +user_email+ (String) => email of user to add to group
	#
  # * *return*
  #   - +Boolean+ indication of user addition
	def add_user_to_group(group_name, user_role, user_email)
		if USER_GROUP_ROLES.include?(user_role)
			path = self.api_root + "/api/groups/#{group_name}/#{user_role}/#{user_email}"
			process_firecloud_request(:put, path)
		else
			raise RuntimeError.new("Invalid FireCloud user group role: #{user_role}; must be one of '#{USER_GROUP_ROLES.join(', ')}'")
		end
	end

	# remove another user to a user group the current user owns
	#
  # * *params*
  #   - +group_name+ (String) => name of requested group
	#   - +user_role+ (String) => role of user to add to group (must be member or admin)
	#   - +user_email+ (String) => email of user to add to group
	#
  # * *return*
  #   - +Boolean+ indication of user removal
	def delete_user_from_group(group_name, user_role, user_email)
		if USER_GROUP_ROLES.include?(user_role)
			path = self.api_root + "/api/groups/#{group_name}/#{user_role}/#{user_email}"
			process_firecloud_request(:delete, path)
		else
			raise RuntimeError.new("Invalid FireCloud user group role: #{user_role}; must be one of '#{USER_GROUP_ROLES.join(', ')}'")
		end
	end

	# request access to a user group as the current user
	#
  # * *params*
  #   - +group_name+ (String) => name of requested group
	#
  # * *return*
  #   - +Boolean+ indication of request submission
	def request_user_group(group_name)
		path = self.api_root + "/api/groups/#{group_name}/requestAccess"
		process_firecloud_request(:post, path)
	end

  ##
  ## PROFILE/BILLING METHODS
  ##

	# get a user's profile status
	#
  # * *return*
  #   - +Hash+ of user registration properties, including email, userID and enabled features
	def get_registration
		path = self.api_root + '/register'
		process_firecloud_request(:get, path)
	end

  # register a new user or update a user's profile in FireCloud
  #
  # * *params*
  #   - +profile_contents+ (Hash) => complete FireCloud profile information, see https://api.firecloud.org/#!/Profile/setProfile for details
  #
  # * *return*
  #   - +Hash+ of user's registration status information (see FireCloudClient#registration)
  def set_profile(profile_contents)
		path = self.api_root + '/register/profile'
		process_firecloud_request(:post, path, profile_contents.to_json)
	end

	# get a user's profile status
	#
  # * *return*
  #   - +Hash+ of key/value pairs of information stored in a user's FireCloud profile
  def get_profile
		path = self.api_root + '/register/profile'
		process_firecloud_request(:get, path)
	end

  # check if a user is registered (via access token)
  #
  # * *return*
  #   - +Boolean+ indication of whether or not user is registered
  def registered?
		begin
			self.get_registration
			true
		rescue RuntimeError => e
			# if user isn't registered, error message should beging with '404 Not Found'
			if e.message.starts_with?('404')
				false
			else
				# something else happened, so raise exception
				raise e
			end
		end
	end

	# list billing projects for a given user
	#
  # * *return*
  #   - +Array+ of Hashes of billing projects
	def get_billing_projects
		path = self.api_root + '/api/profile/billing'
		process_firecloud_request(:get, path)
	end

	# list billing accounts for a given user
	#
  # * *return*
  #   - +Array+ of Hashes of billing accounts
  def get_billing_accounts
		path = self.api_root + '/api/profile/billingAccounts'
		process_firecloud_request(:get, path)
	end

	# create a FireCloud billing project
	#
  # * *params*
  #   - +project_name+ (String) => name of new billing project
	#   - +billing_account+ (String) => ID of billing project (must start with billingAccounts/)
	#
  # * *return*
  #   - +Array+ of FireCloud user accounts
  def create_billing_project(project_name, billing_account)
		if billing_account.start_with?('billingAccounts/')
			path = self.api_root + '/api/billing'
			project_payload = {
					projectName: project_name,
					billingAccount: billing_account
			}.to_json
			process_firecloud_request(:post, path, project_payload)
		else
			raise RuntimeError.new("Invalid billing account: #{billing_account}; must begin with 'billingAccounts/'")
		end
	end

	# list all members of a FireCloud billing project
	#
  # * *params*
  #   - +project_id+ (String) => ID of billing project (must start with billingAccounts/)
	#
  # * *return*
  #   - +Array+ of FireCloud user accounts
	def get_billing_project_members(project_id)
		path = self.api_root + "/api/billing/#{project_id}/members"
		process_firecloud_request(:get, path)
	end

	# add a member to a FireCloud billing project
	#
  # * *params*
  #   - +project_id+ (String) => ID of billing project (must start with billingAccounts/)
	#   - +role+ (String) => role of member being added (user/owner)
	#   - +email+ (String) => email of member being added
	#
  # * *return*
  #   - +Array+ of FireCloud user accounts
	def add_user_to_billing_project(project_id, role, email)
		if BILLING_PROJECT_ROLES.include?(role)
			path = self.api_root + "/api/billing/#{project_id}/#{role}/#{email}"
			process_firecloud_request(:put, path)
		else
			raise RuntimeError.new("Invalid billing account role: #{role}; must be a member of '#{BILLING_PROJECT_ROLES.join(', ')}'")
		end
	end

	# remove a member from a FireCloud billing project
	#
  # * *params*
  #   - +project_id+ (String) => ID of billing project (must start with billingAccounts/)
	#   - +role+ (String) => role of member being added (user/owner)
	#   - +email+ (String) => email of member being added
	#
  # * *return*
  #   - +Array+ of FireCloud user accounts
	def delete_user_from_billing_project(project_id, role, email)
		if BILLING_PROJECT_ROLES.include?(role)
			path = self.api_root + "/api/billing/#{project_id}/#{role}/#{email}"
			process_firecloud_request(:delete, path)
		else
			raise RuntimeError.new("Invalid billing account role: #{role}; must be a member of '#{BILLING_PROJECT_ROLES.join(', ')}'")
		end
	end

	#######
	##
	## GOOGLE CLOUD STORAGE METHODS
	##
	## All methods are convenience wrappers around google-cloud-storage methods
	## see https://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-storage/v0.23.2 for more detail
	##
	#######

	# generic handler to process GCS method with retries and error handling
  #
  # * *params*
  #   - +method_name+ (String, Symbol) => name of FireCloudClient GCS method to execute
  #   - +params+ (Array) => array of method parameters (passed with splat operator, so does not need to be an actual array)
  #
  # * *return*
  #   - Object depends on method, can be one of the following: +Google::Cloud::Storage::Bucket+, +Google::Cloud::Storage::File+,
  #     +Google::Cloud::Storage::FileList+, +Boolean+, +File+, or +String+

  def execute_gcloud_method(method_name, *params)
		@retries ||= 0
		if @retries < MAX_RETRY_COUNT
			begin
				self.send(method_name, *params)
			rescue => e
				@error = e.message
				Rails.logger.info "#{Time.now}: error calling #{method_name} with #{params.join(', ')}; #{e.message} -- retry ##{@retries}"
				@retries += 1
				execute_gcloud_method(method_name, *params)
			end
		else
			Rails.logger.info "#{Time.now}: Retry count exceeded: #{@error}"
			raise RuntimeError.new "#{@error}"
		end
	end

	# retrieve a workspace's GCP bucket
	#
  # * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of workspace
	#
  # * *return*
  #   - +Google::Cloud::Storage::Bucket+ object
	def get_workspace_bucket(workspace_namespace, workspace_name)
		workspace = self.get_workspace(workspace_namespace, workspace_name)
		bucket_name = workspace['workspace']['bucketName']
		self.storage.bucket bucket_name
	end

	# retrieve all files in a GCP bucket of a workspace
	#
  # * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of workspace
	#   - +opts+ (Hash) => hash of optional parameters, see
	#     https://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-storage/v0.23.2/google/cloud/storage/bucket?method=files-instance
	#
  # * *return*
  #   - +Google::Cloud::Storage::File::List+
	def get_workspace_files(workspace_namespace, workspace_name, opts={})
		bucket = self.get_workspace_bucket(workspace_namespace, workspace_name)
		bucket.files(opts)
	end

	# retrieve single study_file in a GCP bucket of a workspace
	#
  # * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of workspace
	#   - +filename+ (String) => name of file
	#
  # * *return*
  #   - +Google::Cloud::Storage::File+
	def get_workspace_file(workspace_namespace, workspace_name, filename)
		bucket = self.get_workspace_bucket(workspace_namespace, workspace_name)
		bucket.file filename
	end

	# add a file to a workspace bucket
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of workspace
	#   - +filepath+ (String) => path to file
	#   - +filename+ (String) => name of file
	#   - +opts+ (Hash) => extra options for create_file, see
	#     https://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-storage/v0.23.2/google/cloud/storage/bucket?method=create_file-instance
	#
	# * *return*
	#   - +Google::Cloud::Storage::File+
	def create_workspace_file(workspace_namespace, workspace_name, filepath, filename, opts={})
		bucket = self.get_workspace_bucket(workspace_namespace, workspace_name)
		bucket.create_file filepath, filename, opts
	end

	# copy a file to a new location in a workspace bucket
	#
  # * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of workspace
	#   - +filename+ (String) => name of target file
	#   - +destination_name+ (String) => destination of new file
	#   - +opts+ (Hash) => extra options for create_file, see
	#     https://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-storage/v0.23.2/google/cloud/storage/bucket?method=create_file-instance
	#
  # * *return*
  #   - +Google::Cloud::Storage::File+
	def copy_workspace_file(workspace_namespace, workspace_name, filename, destination_name, opts={})
		file = self.get_workspace_file(workspace_namespace, workspace_name, filename)
		file.copy destination_name, opts
	end

	# delete a file to a workspace bucket
	#
  # * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of workspace
	#   - +filename+ (String) => name of file
	#
  # * *return*
  #   - +Boolean+ indication of file deletion
	def delete_workspace_file(workspace_namespace, workspace_name, filename)
		file = self.get_workspace_file(workspace_namespace, workspace_name, filename)
		begin
			file.delete
		rescue => e
			logger.info("#{Time.now}: failed to delete workspace file #{filename} with error #{e.message}")
			false
		end
	end

	# retrieve single file in a GCP bucket of a workspace and download locally to portal (likely for parsing)
	#
	# * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of workspace
	#   - +filename+ (String) => name of file
	#   - +destination+ (String) => destination path for downloaded file
	#   - +opts+ (Hash) => extra options for signed_url, see
	#     https://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-storage/v0.23.2/google/cloud/storage/file?method=signed_url-instance
	#
  # * *return*
  #   - +File+ object
	def download_workspace_file(workspace_namespace, workspace_name, filename, destination, opts={})
		file = self.get_workspace_file(workspace_namespace, workspace_name, filename)
		# create a valid path by combining destination directory and filename, making sure no double / exist
		end_path = [destination, filename].join('/').gsub(/\/\//, '/')
		# gotcha in case file is in a subdirectory
		if filename.include?('/')
			path_parts = filename.split('/')
			path_parts.pop
			directory = File.join(destination, path_parts)
			FileUtils.mkdir_p directory
		end
		file.download end_path, opts
	end

	# generate a signed url to download a file that isn't public (set at study level)
	#
  # * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of workspace
	#   - +filename+ (String) => name of file
	#   - +opts+ (Hash) => extra options for signed_url, see
	#     https://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-storage/v0.23.2/google/cloud/storage/file?method=signed_url-instance
	#
  # * *return*
  #   - +String+ signed URL
	def generate_signed_url(workspace_namespace, workspace_name, filename, opts={})
		file = self.get_workspace_file(workspace_namespace, workspace_name, filename)
		file.signed_url(opts)
	end

	# retrieve all files in a GCP directory
	#
  # * *params*
	#   - +workspace_namespace+ (String) => namespace of workspace
	#   - +workspace_name+ (String) => name of workspace
	#   - +directory+ (String) => name of directory in bucket
	#   - +opts+ (Hash) => hash of optional parameters, see
  #     https://googlecloudplatform.github.io/google-cloud-ruby/#/docs/google-cloud-storage/v0.23.2/google/cloud/storage/bucket?method=files-instance
	#
  # * *return*
  #   - +Google::Cloud::Storage::File::List+
	def get_workspace_directory_files(workspace_namespace, workspace_name, directory, opts={})
		# makes sure directory ends with '/', otherwise append to prevent spurious matches
		directory += '/' unless directory.last == '/'
		opts.merge!(prefix: directory)
		self.get_workspace_files(workspace_namespace, workspace_name, opts)
	end

  #######
  ##
  ## UTILITY METHODS
	##
  #######

  # create a map of workspace entities based on a list of names and a type
  #
  # * *params*
  #   - +entity_names+ (Array) => array of entity names
  #   - +entity_type+ (String) => type of entity that all names belong to
  #
  # * *return*
  #   - +Array+ of Hash objects: {entityName: [name], entityType: entity_type}
  def create_entity_map(entity_names, entity_type)
    map = []
    entity_names.each do |name|
      map << {entityName: name, entityType: entity_type}
    end
    map
  end

	# check if OK response code was found
	#
  # * *params*
  #   - +code+ (Integer) => integer HTTP response code
	#
  # * *return*
  #   - +Boolean+ of whether or not response is a known 'OK' response
	def ok?(code)
		[200, 201, 202, 204, 206].include?(code)
	end

  # merge hash of options into single URL query string
  #
  # * *params*
  #   - +opts+ (Hash) => hash of query parameter key/value pairs
  #
  # * *return*
  #   - +String+ of concatenated query params
  def merge_query_options(opts)
		# return nil if opts is empty, else concat
		opts.blank? ? nil : '?' + opts.to_a.map {|k,v| "#{k}=#{v}"}.join("&")
	end

  # return a more user-friendly error message
  #
  # * *params*
  #   - +error+ (RestClient::Exception) => an RestClient error object
  #
  # * *return*
  #   - +String+ representation of complete error message, with http body if present
	def parse_error_message(error)
		if error.http_body.blank?
			error.message
		else
			begin
				error_hash = JSON.parse(error.http_body)
				if error_hash.has_key?('message')
					# check if hash can be parsed further
					message = error_hash['message']
					if message.index('{').nil?
						return message
					else
						# attempt to extract nested JSON from message
						json_start = message.index('{')
						json = message[json_start, message.size + 1]
						new_message = JSON.parse(json)
						if new_message.has_key?('message')
							new_message['message']
						else
							new_message
						end
					end
				else
					return error.message
				end
			rescue => e
				Rails.logger.error e.message
				error.message + ': ' + error.http_body
			end
		end
	end
end