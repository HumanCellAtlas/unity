class SiteController < ApplicationController

  before_action :check_firecloud_registration

  def index
    @methods = fire_cloud_client.get_methods(namespace: 'single-cell-portal')
  end

  private

  # check if a signed-in user is a FireCloud user
  def check_firecloud_registration
    if user_signed_in?

    end
  end
end
