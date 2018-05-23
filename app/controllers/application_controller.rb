class ApplicationController < ActionController::Base
  @@fire_cloud_client = FireCloudClient.new

  def fire_cloud_client
    @@fire_cloud_client
  end
end
