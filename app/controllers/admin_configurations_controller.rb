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

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_admin_configuration
      @admin_configuration = AdminConfiguration.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def admin_configuration_params
      params.require(:admin_configuration).permit(:config_type, :value_type, :value, configuration_options_attributes: [:id, :name, :value, :_destroy])
    end
end
