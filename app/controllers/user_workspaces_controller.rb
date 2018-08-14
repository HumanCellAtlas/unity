class UserWorkspacesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user_workspace, only: [:show, :destroy]
  before_action :set_user_projects, only: [:new, :create]
  before_action :set_reference_analysis, only: [:new]

  # GET /user_workspaces
  # GET /user_workspaces.json
  def index
    @user_workspaces = UserWorkspace.all
  end

  # GET /user_workspaces/1
  # GET /user_workspaces/1.json
  def show
    @submissions = []
    begin
      user_client = user_fire_cloud_client(current_user, @user_workspace.namespace)
      @submissions = user_client.get_workspace_submissions(@user_workspace.namespace, @user_workspace.name)
    rescue => e
      Rails.logger.info "Cannot retrieve submissions for user_workspace '#{@user_workspace.full_name}': #{e.message}"
    end
  end

  # GET /user_workspaces/new
  def new
    @user_workspace = UserWorkspace.new(user_id: current_user.id, reference_analysis_id: @reference_analysis.id)
    @user_workspace.name = @user_workspace.default_name
  end

  # POST /user_workspaces
  # POST /user_workspaces.json
  def create
    @user_workspace = UserWorkspace.new(user_workspace_params)

    respond_to do |format|
      if @user_workspace.save
        format.html { redirect_to user_workspace_path(project: @user_workspace.namespace, name: @user_workspace.name), notice: "'#{@user_workspace.name}' was successfully created." }
        format.json { render :show, status: :created, location: @user_workspace }
      else
        @reference_analysis = @user_workspace.reference_analysis
        format.html { render :new }
        format.json { render json: @user_workspace.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /user_workspaces/1
  # DELETE /user_workspaces/1.json
  def destroy
    name = @user_workspace.name
    # remove workspace, unless user requests it to persist
    begin
      unless params[:persist] == 'true'
        user_client = user_fire_cloud_client(current_user, @user_workspace.namespace)
        Rails.logger.info "Removing user_workspace: #{@user_workspace.full_name}"
        user_client.delete_workspace(@user_workspace.namespace, @user_workspace.name)
      end
      @user_workspace.destroy
      respond_to do |format|
        format.html { redirect_to user_workspaces_path, notice: "'#{name}' was successfully destroyed." }
        format.json { head :no_content }
      end
    rescue => e
      Rails.logger.error "Error removing benchmark workspace '#{name}': #{e.message}"
      redirect_to user_workspace_path, alert: "We were unable to remove benchmarking workspace '#{name}' due to an error: #{e.message}" and return
    end
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_user_workspace
    if params[:name].present? && params[:project].present?
      project = Project.find_by(user_id: current_user.id, namespace: params[:project])
      @user_workspace = UserWorkspace.find_by(name: params[:name], project_id: project.id, user_id: current_user.id)
    else
      @user_workspace = UserWorkspace.find(params[:id])
    end
  end

  def set_user_projects
    @projects = Project.owned_by(current_user)
  end

  def set_reference_analysis
    @reference_analysis = ReferenceAnalysis.find(params[:reference_analysis_id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def user_workspace_params
    params.require(:user_workspace).permit(:name, :project_id, :user_id, :reference_analysis_id)
  end
end
