class AdminConfigurationsController < ApplicationController
  before_action :authenticate_user!
  before_action :authenticate_admin
  before_action :set_admin_configuration, only: [:show, :edit, :update, :destroy]

  # GET /admin_configurations
  # GET /admin_configurations.json
  def index
    @admin_configurations = AdminConfiguration.where.not(config_type: AdminConfiguration::FIRECLOUD_ACCESS_NAME)
  end

  # GET /admin_configurations/1
  # GET /admin_configurations/1.json
  def show
  end

  # GET /admin_configurations/new
  def new
    @admin_configuration = AdminConfiguration.new
  end

  # GET /admin_configurations/1/edit
  def edit
  end

  # POST /admin_configurations
  # POST /admin_configurations.json
  def create
    @admin_configuration = AdminConfiguration.new(admin_configuration_params)

    respond_to do |format|
      if @admin_configuration.save
        format.html { redirect_to admin_configurations_path, notice: "#{@admin_configuration.display_name} was successfully created." }
        format.json { render :show, status: :created, location: @admin_configuration }
      else
        format.html { render :new }
        format.json { render json: @admin_configuration.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /admin_configurations/1
  # PATCH/PUT /admin_configurations/1.json
  def update
    respond_to do |format|
      if @admin_configuration.update(admin_configuration_params)
        format.html { redirect_to admin_configurations_path, notice: "#{@admin_configuration.display_name} was successfully updated." }
        format.json { render :show, status: :ok, location: @admin_configuration }
      else
        format.html { render :edit }
        format.json { render json: @admin_configuration.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /admin_configurations/1
  # DELETE /admin_configurations/1.json
  def destroy
    name = @admin_configuration.display_name
    @admin_configuration.destroy
    respond_to do |format|
      format.html { redirect_to admin_configurations_path, notice: "Admin configuration: #{name} was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  # retrieve the firecloud registration for any of the Unity service accounts
  def get_service_account_profile
    @client = params[:account] == 'gcs_admin' ? ApplicationController.gcs_client : ApplicationController.fire_cloud_client
    @service_account_email = @client.issuer

    @fire_cloud_profile = FireCloudProfile.new
    begin
      profile = @client.get_profile
      profile['keyValuePairs'].each do |attribute|
        if @fire_cloud_profile.respond_to?("#{attribute['key']}=")
          @fire_cloud_profile.send("#{attribute['key']}=", attribute['value'])
        end
      end
    rescue => e
      logger.info "Unable to retrieve FireCloud profile for #{@client.issuer}: #{e.message}"
    end
  end

  # register or update the FireCloud profile of the portal service account
  def update_service_account_profile
    @client = params[:account] == 'gcs_admin' ? ApplicationController.gcs_client : ApplicationController.fire_cloud_client
    @fire_cloud_profile = FireCloudProfile.new(profile_params)

    begin
      if @fire_cloud_profile.valid?
        @client.set_profile(profile_params)
        @notice = "Your FireCloud profile has been successfully updated."
        redirect_to admin_configurations_path, notice: "The Unity service account for #{@client.issuer} FireCloud profile has been successfully updated."
      else
        logger.info "Error in updating FireCloud profile for #{@client.issuer}: #{@fire_cloud_profile.errors.full_messages}"
        respond_to do |format|
          format.html { render :get_service_account_profile, status: :unprocessable_entity}
          format.json { render @fire_cloud_profile.errors, status: :unprocessable_entity}
        end
      end
    rescue => e
      logger.error "#{Time.now}: unable to update Unity service account for #{@client.issuer} FireCloud registration: #{e.message}"
      @alert = "Unable to update The Unity service account for #{@client.issuer} FireCloud profile: #{e.message}"
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_admin_configuration
      @admin_configuration = AdminConfiguration.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def admin_configuration_params
      params.require(:admin_configuration).permit(:config_type, :value_type, :value, configuration_options_attributes: [:id, :name, :value, :_destroy])
    end

    # parameters for service account profile
    def profile_params
      params.require(:fire_cloud_profile).permit(:contactEmail, :email, :firstName, :lastName, :institute, :institutionalProgram,
                                              :nonProfitStatus, :pi, :programLocationCity, :programLocationState,
                                              :programLocationCountry, :title)
    end
end
