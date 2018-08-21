class SiteController < ApplicationController

  before_action :check_profile_status, only: [:profile, :update_user_profile]
  before_action :check_firecloud_registration, except: [:profile, :update_user_profile]
  before_action :authenticate_user!, except: [:index, :view_pipeline_wdl]

  def index
    # load available 'blessed' workflows
    reference_analyses = ReferenceAnalysis.all
    @methods = []

    reference_analyses.each do |analysis|
      workflow_namespace, workflow_name, workflow_snapshot = analysis.extract_wdl_keys(:analysis_wdl)
      methods = fire_cloud_client.get_methods(namespace: workflow_namespace, name: workflow_name, snapshotId: workflow_snapshot)
      methods.each do |method|
        @methods << {
            reference_analysis_id: analysis.id,
            namespace: method['namespace'],
            name: method['name'],
            snapshot: method['snapshotId'],
            synopsis: method['synopsis'],
            identifier: "#{method['namespace']}-#{method['name']}-#{method['snapshotId']}",
            reference_workspace: analysis.display_name,
            documentation_link: analysis.options[:documentation_link]
        }
      end
    end

    @user_workspaces = UserWorkspace.owned_by(current_user)
  end

  def profile
    begin
      @fire_cloud_profile = FireCloudProfile.new
      begin
        profile = user_fire_cloud_client(current_user).get_profile
        profile['keyValuePairs'].each do |attribute|
          if @fire_cloud_profile.respond_to?("#{attribute['key']}=")
            @fire_cloud_profile.send("#{attribute['key']}=", attribute['value'])
          end
        end
      rescue => e
        logger.info "Unable to retrieve FireCloud profile for #{current_user.email}: #{e.message}"
      end
    rescue RuntimeError => e
      logger.info "Unable to retrieve FireCloud profile for #{current_user.email}: #{e.message}"
      redirect_to site_path, alert: "We are unable to load your profile at the moment - please try again later."
    end
  end

  def update_user_profile
    begin
      @fire_cloud_profile = FireCloudProfile.new(profile_params)
      if @fire_cloud_profile.valid?
        user_fire_cloud_client(current_user).set_profile(profile_params)
        # log that user has registered so we can use this elsewhere
        if !current_user.registered_for_firecloud
          current_user.update(registered_for_firecloud: true)
        end
        @notice = "Your FireCloud profile has been successfully updated."
        # now check if user is part of Unity user group
        current_user.add_to_unity_user_group
        redirect_to profile_path, notice: 'Your FireCloud profile has been successfully updated.' and return
      else
        logger.info "Error in updating FireCloud profile for #{current_user.email}: #{@fire_cloud_profile.errors.full_messages}"
        respond_to do |format|
          format.html { render :profile, status: :unprocessable_entity}
          format.json { render @fire_cloud_profile.errors, status: :unprocessable_entity}
        end
      end
    rescue RuntimeError => e
      logger.info "Unable to update FireCloud profile for #{current_user.email}: #{e.message}"
      redirect_to profile_path, alert: "An error occurred when trying to update your FireCloud profile: #{e.message}" and return
    end
  end

  # view WDL contents of pipeline
  def view_pipeline_wdl
    begin
      pipeline_attr = [params[:namespace], params[:name], params[:snapshot]]
      @pipeline_wdl = fire_cloud_client.get_method(params[:namespace], params[:name], params[:snapshot], true)
      @pipeline_name = pipeline_attr.join('/')
      @pipeline_id = pipeline_attr.join('-')
    rescue RuntimeError => e
      @pipeline_wdl = "We're sorry, but we could not load the requested workflow object.  Please try again later.\n\nError: #{e.message}"
      logger.error "Unable to load WDL for #{params[:namespace]}:#{params[:name]}:#{params[:snapshot]}; #{e.message}"
    end
  end

  private

  def profile_params
    params.require(:fire_cloud_profile).permit(:contactEmail, :email, :firstName, :lastName, :institute, :institutionalProgram,
                                              :nonProfitStatus, :pi, :programLocationCity, :programLocationState,
                                              :programLocationCountry, :title)
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

  def check_profile_status
    unless ApplicationController.fire_cloud_client.services_available?('Thurloe')
      redirect_to site_path, alert: "User profiles are currently unavailable.  Please try again later." and return
    end
  end
end
