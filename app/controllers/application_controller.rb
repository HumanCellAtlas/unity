class ApplicationController < ActionController::Base

  # instantiate singleton FireCloudClient to reuse OAuth token as much as possible
  @@fire_cloud_client = FireCloudClient.new

  # getters for FireCloudClient
  def self.fire_cloud_client
    @@fire_cloud_client
  end

  def fire_cloud_client
    @@fire_cloud_client
  end

  # instantiate a user-scoped firecloud client
  def user_fire_cloud_client(user, project=FireCloudClient::PROJECT_NAMESPACE)
    FireCloudClient.new(user, project)
  end

  # auth action for portal admins
  def authenticate_admin
    unless current_user.admin?
      redirect_to site_path, alert: 'You do not have permission to access that page.' and return
    end
  end

  # overriding default new_session_path since we aren't using database_authenticatable
  def new_session_path(scope)
    new_user_session_path
  end

end
