class SiteController < ApplicationController

  before_action :check_firecloud_registration

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
  end

  private

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
          redirect_to profile_path(current_user.uid), notice: 'You must register before continuing' && return
        end
      end
    end
  end
end
