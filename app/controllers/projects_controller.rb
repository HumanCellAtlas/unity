class ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [:show, :workspaces, :destroy]
  before_action :verify_project_ownership, only: [:show, :destroy]
  before_action :check_firecloud_status
  before_action :set_available_projects, only: [:new, :create]
  before_action :set_available_billing, only: [:new_from_scratch, :create_from_scratch]

  # GET /projects
  # GET /projects.json
  def index
    @projects = Project.owned_by(current_user)
  end

  # GET /projects/1
  # GET /projects/1.json
  def show
    if @project.user_is_owner?
      begin
        @project_members = user_fire_cloud_client(current_user, @project.namespace).get_billing_project_members(@project.namespace)
      rescue RuntimeError => e
        logger.error "Error retrieving project members for #{@project.namespace}: #{e.message}"
      end
    end
  end

  # GET /projects/new
  def new
    @project = Project.new(user_id: current_user.id)
  end

  # GET /projects/new/from_scratch
  def new_from_scratch
    @project = Project.new(user_id: current_user.id)
  end

  # POST /projects
  # POST /projects.json
  def create
    @project = Project.new(project_params)

    respond_to do |format|
      if @project.save
        format.html { redirect_to @project, notice: "'#{@project.namespace}' was successfully registered." }
        format.json { render :show, status: :created, location: @project }
      else
        format.html { render :new }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  def create_from_scratch
    @project = Project.new(project_params)
    if params[:billing_account].blank?
    else

    end
    if project_params[:namespace].present?
      begin
        # attempt to create project in FireCloud now in order to validate @project
        client = user_fire_cloud_client(current_user, @project.namespace)
        client.create_billing_project(@project.namespace, params[:billing_account])
      rescue RuntimeError => e
        logger.error "Error in creating new billing project #{@project.namespace}: #{e.message}"
        @project.errors.add(:base, "Unable to create project #{@project.namespace}: #{e.message}")
        # immediately exit and do not attempt to save project
        logger.info 'in first block'
        respond_to do |format|
          format.html { render :new_from_scratch }
          format.json { render json: @project.errors, status: :unprocessable_entity }
        end
      end
    end

    respond_to do |format|
      logger.info 'in second block'
      if @project.save
        format.html { redirect_to @project, notice: "'#{@project.namespace}' was successfully created and registered." }
        format.json { render :show, status: :created, location: @project }
      else
        format.html { render :new_from_scratch }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # get a list of all workspaces in a project
  def workspaces
    client = user_fire_cloud_client(current_user, @project.namespace)
    @workspaces = client.workspaces(@project.namespace)
    @computes = {}
    Parallel.map(@workspaces, in_threads: 3) do |workspace|
      workspace_name = workspace['workspace']['name']
      acl = client.get_workspace_acl(@project.namespace, workspace_name)
      @computes[workspace_name] = []
      acl['acl'].each do |user, permission|
        @computes[workspace_name] << {"#{user}" => {can_compute: permission['canCompute'], access_level: permission['accessLevel']} }
      end
    end
  end

  # DELETE /projects/1
  # DELETE /projects/1.json
  def destroy
    namespace = @project.namespace
    @project.destroy
    respond_to do |format|
      format.html { redirect_to projects_url, notice: "'#{namespace}' was successfully removed from Unity.  The source project in FireCloud has not been changed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_project
      @project = Project.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def project_params
      params.fetch(:project, {}).permit(:namespace, :user_id)
    end

    def set_available_projects
      projects = user_fire_cloud_client(current_user).get_billing_projects.keep_if {|fc_proj| fc_proj['creationStatus'] == 'Ready'}
      @available_projects = projects.map {|project| project['projectName']}
    end

    def set_available_billing
      accounts = user_fire_cloud_client(current_user).get_billing_accounts.keep_if {|account| account['firecloudHasAccess']}
      @available_billing = accounts.map {|account| [account['displayName'], account['accountName']]}
    end

    def verify_project_ownership
      unless @project.user == current_user
        alert = 'You do not have permission to perform that action.'
        respond_to do |format|
          format.html {redirect_to projects_path, alert: alert and return}
          format.js {render js: "alert('#{alert}');"}
          format.json {render json: {error: alert}, status: 403}
        end
      end
    end

    def check_firecloud_status
      unless ApplicationController.fire_cloud_client.services_available?('Thurloe', 'Sam')
        redirect_to site_path, alert: "User billing projects/workspaces are currently unavailable.  Please try again later." and return
      end
    end
end
