class SiteController < ApplicationController

  before_action :check_firecloud_registration
  before_action :authenticate_user!, only: :profile

  def index
    # load available 'blessed' workflows
    workflow_configs = AdminConfiguration.where(config_type: 'Workflow Name')
    @methods = []
    if workflow_configs.present?
      workflow_configs.each do |config|
        workflow_namespace, workflow_name, workflow_snapshot = config.value.split('/')
        @methods += fire_cloud_client.get_methods(namespace: workflow_namespace, name: workflow_name, snapshotId: workflow_snapshot)
      end
    end
    project_config = AdminConfiguration.find_by_config_type('Unity FireCloud Project')
    @workspaces = []
    if project_config.present?
      project_name = project_config.value
      @workspaces = fire_cloud_client.workspaces(project_name)
    end
    @user_workspaces = []
  end

  def profile
    begin
      user_client = FireCloudClient.new(current_user, FireCloudClient::PORTAL_NAMESPACE)
      profile = user_client.get_profile
      profile['keyValuePairs'].each do |attribute|
        @profile_info[attribute['key']] = attribute['value']
      end
    rescue => e
      logger.info "#{Time.now}: unable to retrieve FireCloud profile for #{current_user.email}: #{e.message}"
      redirect_to site_path, alert: "We are unable to load your profile at the moment - please try again later."
    end
  end

  def update_user_profile
    begin
      user_client = FireCloudClient.new(current_user, FireCloudClient::PORTAL_NAMESPACE)
      user_client.set_profile(profile_params)
      # log that user has registered so we can use this elsewhere
      if !current_user.registered_for_firecloud
        current_user.update(registered_for_firecloud: true)
      end
      @notice = "Your FireCloud profile has been successfully updated."
      # now check if user is part of 'all-portal' user group
      user_group_config = AdminConfiguration.find_by(config_type: 'Portal FireCloud User Group')
      if user_group_config.present?
        group_name = user_group_config.value
        user_group = Study.firecloud_client.get_user_group(group_name)
        unless user_group['membersEmails'].include?(current_user.email)
          logger.info "#{Time.now}: adding #{current_user.email} to #{group_name} user group"
          Study.firecloud_client.add_user_to_group(group_name, 'member', current_user.email)
          logger.info "#{Time.now}: user group registration complete"
        end
      end
    rescue => e
      logger.info "#{Time.now}: unable to update FireCloud profile for #{current_user.email}: #{e.message}"
      @alert = "An error occurred when trying to update your FireCloud profile: #{e.message}"
    end
  end

  # view WDL contents of pipeline
  def view_pipeline_wdl
    begin
      pipeline_attr = [params[:namespace], params[:name], params[:snapshot]]
      @pipeline_wdl = fire_cloud_client.get_method(params[:namespace], params[:name], params[:snapshot], true)
      if @pipeline_wdl.is_a?(Hash)
        @pipeline_wdl = @pipeline_wdl['payload']
      end
      @pipeline_name = pipeline_attr.join('/')
      @pipeline_id = pipeline_attr.join('-')
    rescue => e
      @pipeline_wdl = "We're sorry, but we could not load the requested workflow object.  Please try again later.\n\nError: #{e.message}"
      logger.error "#{Time.now}: unable to load WDL for #{params[:namespace]}:#{params[:name]}:#{params[:snapshot]}; #{e.message}"
    end
  end

  private

  def profile_params
    params.require(:firecloud_profile).permit(:contactEmail, :email, :firstName, :lastName, :institute, :institutionalProgram,
                                              :nonProfitStatus, :pi, :programLocationCity, :programLocationState,
                                              :programLocationCountry, :title)
  end

  # check if a signed-in user is a FireCloud user
  def check_firecloud_registration
    if user_signed_in?
      if current_user.registered_for_firecloud?
        true # do nothing as we're ok
      else
        client = FireCloudClient.new(current_user, 'foo') # project name doesn't matter in this instance
        if client.registered?
          logger.info "Updating #{current_user.email} registration status to true"
          current_user.update(registered_for_firecloud: true)
          true
        else
          redirect_to profile_path, notice: 'You must register before continuing' && return
        end
      end
    end
  end
end
