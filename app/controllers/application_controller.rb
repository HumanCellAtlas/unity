class ApplicationController < ActionController::Base

  # instantiate singleton FireCloudClients to reuse OAuth token as much as possible
  @@fire_cloud_client = FireCloudClient.new
  @@gcs_client = FireCloudClient.new(nil, AdminConfiguration.project_namespace, File.absolute_path(ENV['GCS_ADMIN_SERVICE_ACCOUNT_KEY']))

  # getters for FireCloudClient
  def self.fire_cloud_client
    @@fire_cloud_client
  end

  def fire_cloud_client
    @@fire_cloud_client
  end

  # getters for FireCloudClient GCS admin client
  def self.gcs_client
    @@gcs_client
  end

  def gcs_client
    @@gcs_client
  end

  # instantiate a user-scoped firecloud client
  def user_fire_cloud_client(user, project=AdminConfiguration.project_namespace)
    FireCloudClient.new(user, project)
  end

  # auth action for portal admins
  def authenticate_admin
    unless current_user.admin?
      redirect_to site_path, alert: 'You do not have permission to access that page.' and return
    end
  end

  # auth action for portal admins
  def authenticate_curator
    unless current_user.acts_as_curator?
      redirect_to site_path, alert: 'You do not have permission to access that page.' and return
    end
  end

  # overriding default new_session_path since we aren't using database_authenticatable
  def new_session_path(scope)
    new_user_session_path
  end

  # check if a signed-in user is a FireCloud user and redirect if not
  def check_firecloud_registration
    if user_signed_in?
      if current_user.registered_for_firecloud?
        true # do nothing as we're ok
      else
        if user_fire_cloud_client(current_user).registered?
          current_user.update(registered_for_firecloud: true)
          true
        else
          redirect_to profile_path, notice: 'You must register before using Unity - please fill out the profile form and submit.' and return
        end
      end
    end
  end

  # check if Rawls (submissions), Sam (workspace permissions), and Agora (methods repo) are available before making API calls
  def check_firecloud_availability
    unless ApplicationController.fire_cloud_client.services_available?('Rawls', 'Sam', 'Agora')
      redirect_to site_path, alert: "Workspaces and/or Methods Repository are currently unavailable.  Please try again later." and return
    end
  end
end
