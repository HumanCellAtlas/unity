class UserWorkspacesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user_workspace, except: [:index, :new, :create]
  before_action :set_user_projects, only: [:new, :create]
  before_action :set_reference_analysis, only: [:new]
  before_action :set_user_analysis, only: [:update_user_analysis, :create_benchmark_analysis, :submit_benchmark_analysis]
  before_action :check_firecloud_registration, except: [:index]
  before_action :check_firecloud_availability, except: [:index]
  before_action :load_valid_submissions, only: [:show, :get_workspace_submissions, :create_user_analysis, :update_user_analysis]

  # GET /user_workspaces
  # GET /user_workspaces.json
  def index
    @user_workspaces = UserWorkspace.owned_by(current_user)
  end

  # GET /user_workspaces/1
  # GET /user_workspaces/1.json
  def show
    @user_analysis = @user_workspace.user_analysis
    if @user_analysis.nil?
      @user_analysis = @user_workspace.build_user_analysis(user: @user_workspace.user)
      @user_analysis.namespace = @user_analysis.default_namespace
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
    message = "'#{name}' was successfully destroyed."
    # remove workspace, unless user requests it to persist
    begin
      unless params[:persist] == 'true'
        begin
          logger.info "Removing user_workspace: #{@user_workspace.full_name}"
          user_fire_cloud_client(current_user).delete_workspace(@user_workspace.namespace, @user_workspace.name)
        rescue => e
          logger.info "Unable to remove user_workspace: #{@user_workspace.full_name} due to error: #{e.message}"
          message += " Unity was unable to remove the associated workspace due to an error: #{e.message}"
        end
      end
      @user_workspace.destroy
      respond_to do |format|
        format.html { redirect_to user_workspaces_path, notice: message }
        format.json { head :no_content }
      end
    rescue => e
      logger.error "Error removing benchmark workspace '#{name}': #{e.message}"
      redirect_to user_workspaces_path, alert: "We were unable to remove benchmarking workspace '#{name}' due to an error: #{e.message}" and return
    end
  end

  # add a user_analysis to this benchmarking workspace
  def create_user_analysis
    @user_analysis = UserAnalysis.new(user_analysis_params)

    respond_to do |format|
      if @user_analysis.save
        format.html { redirect_to user_workspace_path(project: @user_workspace.namespace, name: @user_workspace.name), notice: "'#{@user_analysis.full_name}' was successfully created." }
        format.json { render :show, status: :created, location: @user_workspace }
      else
        format.html { render :show }
        format.json { render json: @user_analysis.errors, status: :unprocessable_entity }
      end
    end
  end

  # update a user_analysis in this benchmarking workspace
  def update_user_analysis
    @user_analysis = @user_workspace.user_analysis

    respond_to do |format|
      if @user_analysis.update(user_analysis_params)
        format.html { redirect_to user_workspace_path(project: @user_workspace.namespace, name: @user_workspace.name), notice: "'#{@user_analysis.full_name}' was successfully updated." }
        format.json { render :show, status: :created, location: @user_workspace }
      else
        format.html { render :show }
        format.json { render json: @user_analysis.errors, status: :unprocessable_entity }
      end
    end
  end

  # load WDL payload from methods repo
  def get_analysis_wdl_payload
    begin
      namespace, name, snapshot = @user_workspace.reference_analysis.extract_wdl_keys(:analysis_wdl)
      pipeline_attr = [namespace, name, snapshot]
      @pipeline_wdl = fire_cloud_client.get_method(namespace, name, snapshot, true)
      @pipeline_name = pipeline_attr.join('/')
      @pipeline_id = pipeline_attr.join('-')
    rescue RuntimeError => e
      @pipeline_wdl = "We're sorry, but we could not load the requested workflow object.  Please try again later.\n\nError: #{e.message}"
      logger.error "Unable to load WDL for #{params[:namespace]}:#{params[:name]}:#{params[:snapshot]}; #{e.message}"
    end
  end

  # create a benchmark_analysis (custom orchestration workflow) for use in a user_workspace
  def create_benchmark_analysis
    benchmark_analysis_wdl = @user_analysis.create_orchestration_workflow
    user_client = user_fire_cloud_client(current_user)
    if benchmark_analysis_wdl.is_a?(Hash)
      benchmark_analysis_config = @user_analysis.create_orchestration_config(benchmark_analysis_wdl)
      if benchmark_analysis_config.is_a?(Hash)
        @benchmark_analysis = @user_analysis.benchmark_analyses.build(user: @user_workspace.user,
                                                                      name: benchmark_analysis_wdl['name'],
                                                                      namespace: benchmark_analysis_wdl['namespace'],
                                                                      snapshot: benchmark_analysis_wdl['snapshotId'].to_i,
                                                                      configuration_name: benchmark_analysis_config['name'],
                                                                      configuration_namespace: benchmark_analysis_config['namespace'],
                                                                      configuration_snapshot: benchmark_analysis_config['methodConfigVersion'])
        if @benchmark_analysis.save
          # go ahead and submit this new benchmark_analysis
          begin
            submission = user_client.create_workspace_submission(@user_workspace.namespace,
                                                                 @user_workspace.name,
                                                                 @benchmark_analysis.configuration_namespace,
                                                                 @benchmark_analysis.configuration_name)
            redirect_to user_workspace_path(project: @user_workspace.namespace, name: @user_workspace.name),
                        notice: "'#{@benchmark_analysis.full_name}' was successfully created and submitted (submission: #{submission['submissionId']})" and return
          rescue => e
            redirect_to user_workspace_path(project: @user_workspace.namespace, name: @user_workspace.name),
                        alert: "'#{@benchmark_analysis.full_name}' was successfully created, but failed to submit due to an error: #{e.message})" and return
          end
        else
          # redact workflow
          error_msg = @benchmark_analysis.errors.full_messages.join(', ')
          logger.error "Unable to create benchmark analysis for #{@user_analysis.full_name} due to error: #{error_msg}"
          redact_workflow(current_user, benchmark_analysis_wdl['namespace'], benchmark_analysis_wdl['name'], benchmark_analysis_wdl['snapshotId'].to_i)
          redirect_to user_workspace_path(project: @user_workspace.namespace, name: @user_workspace.name),
                      alert: "We were unable to create this benchmark due to the following errors: #{error_msg})" and return
        end
      else
        # redact workflow
        logger.error "Unable to create orchestration config for #{@user_analysis.full_name} due to error: #{benchmark_analysis_config}"
        redact_workflow(current_user, benchmark_analysis_wdl['namespace'], benchmark_analysis_wdl['name'], benchmark_analysis_wdl['snapshotId'].to_i)
        redirect_to user_workspace_path(project: @user_workspace.namespace, name: @user_workspace.name),
                    alert: "We were unable to create this benchmark due to the following errors: #{benchmark_analysis_config}" and return
      end
    else
      logger.error "Unable to create orchestration workflow for #{@user_analysis.full_name} due to error: #{benchmark_analysis_wdl}"
      redirect_to user_workspace_path(project: @user_workspace.namespace, name: @user_workspace.name),
                  alert: "We were unable to create this benchmark due to the following errors: #{benchmark_analysis_wdl}" and return
    end
  end

  # resubmit an existing benchmark_analysis
  def submit_benchmark_analysis
    begin
      @benchmark_analysis = BenchmarkAnalysis.find_by(id: params[:benchmark_analysis_id], user_id: current_user.id)
      if @benchmark_analysis.present?
        call_cache = params[:call_cache].to_i == 1
        submission = user_fire_cloud_client(current_user).create_workspace_submission(@user_workspace.namespace, @user_workspace.name,
                                                                                      @benchmark_analysis.configuration_namespace,
                                                                                      @benchmark_analysis.configuration_name,
                                                                                      nil, nil, call_cache)
        redirect_to user_workspace_path(project: @user_workspace.namespace, name: @user_workspace.name),
                    notice: "'#{@benchmark_analysis.full_name}' was successfully submitted (submission: #{submission['submissionId']})" and return
      else
        redirect_to user_workspace_path(project: @user_workspace.namespace, name: @user_workspace.name),
                    alert: "The requested benchmark analysis was not found." and return
      end
    rescue => e
      redirect_to user_workspace_path(project: @user_workspace.namespace, name: @user_workspace.name),
                  alert: "'#{@benchmark_analysis.full_name}' failed to submit due to an error: #{e.message})" and return
    end
  end

  # get all submissions for a user_workspace
  def get_workspace_submissions
    # submissions are loaded from load_valid_submissions
    render '/user_workspaces/submissions/get_workspace_submissions'
  end

  # get a submission workflow object as JSON, usually as a pre-flight request to getting errors
  def get_submission_workflow
    begin
      submission = user_fire_cloud_client(current_user).get_workspace_submission(@user_workspace.namespace, @user_workspace.name, params[:submission_id])
      render json: submission.to_json
    rescue => e
      logger.error "#{Time.now}: unable to load workspace submission #{params[:submission_id]} in #{@user_workspace.name} due to: #{e.message}"
      render js: "alert('We were unable to load the requested submission due to an error: #{e.message}')"
    end
  end

  # abort a pending workflow submission
  def abort_submission_workflow
    @submission_id = params[:submission_id]
    begin
      user_fire_cloud_client(current_user).abort_workspace_submission(@user_workspace.namespace, @user_workspace.name, @submission_id)
      @notice = "Submission #{@submission_id} was successfully aborted."
      render '/user_workspaces/submissions/abort_submission_workflow'
    rescue => e
      @alert = "Unable to abort submission #{@submission_id} due to an error: #{e.message}"
      render '/user_workspaces/submissions/display_modal'
    end
  end

  # get errors for a failed submission
  def get_submission_errors
    begin
      user_client = user_fire_cloud_client(current_user)
      workflow_ids = params[:workflow_ids].split(',')
      errors = []
      # first check workflow messages - if there was an issue with inputs, errors could be here
      submission = user_client.get_workspace_submission(@user_workspace.namespace,
                                                                                 @user_workspace.name,
                                                                                 params[:submission_id])
      submission['workflows'].each do |workflow|
        if workflow['messages'].any?
          workflow['messages'].each {|message| errors << message}
        end
      end
      # now look at each individual workflow object
      workflow_ids.each do |workflow_id|
        workflow = user_client.get_workspace_submission_workflow(@user_workspace.namespace, @user_workspace.name,
                                                                 params[:submission_id], workflow_id)
        # failure messages are buried deeply within the workflow object, so we need to go through each to find them
        workflow['failures'].each do |workflow_failure|
          errors << workflow_failure['message']
          # sometimes there are extra errors nested below...
          if workflow_failure['causedBy'].any?
            workflow_failure['causedBy'].each do |failure|
              errors << failure['message']
            end
          end
        end
      end
      @error_message = errors.join("<br />")
      render '/user_workspaces/submissions/get_submission_errors'
    rescue => e
      @alert = "Unable to retrieve submission #{@submission_id} error messages due to: #{e.message}"
      render '/user_workspaces/submissions/display_modal'
    end
  end

  # get outputs from a requested submission
  def get_submission_outputs
    begin
      @outputs = []
      user_client = user_fire_cloud_client(current_user)
      submission = user_client.get_workspace_submission(@user_workspace.namespace, @user_workspace.name,
                                                        params[:submission_id])
      submission['workflows'].each do |workflow|
        workflow = user_client.get_workspace_submission_workflow(@user_workspace.namespace, @user_workspace.name,
                                                                 params[:submission_id], workflow['workflowId'])
        workflow['outputs'].each do |output, file_url|
          display_name = file_url.split('/').last
          file_location = file_url.gsub(/gs\:\/\/#{@user_workspace.bucket_id}\//, '')
          output = {display_name: display_name, file_location: file_location}
          @outputs << output
        end
      end
      render '/user_workspaces/submissions/get_submission_outputs'
    rescue => e
      @alert = "Unable to retrieve submission #{@submission_id} outputs due to: #{e.message}"
      render '/user_workspaces/submissions/display_modal'
    end
  end

  # delete all files from a submission
  def delete_submission_files
    begin
      # instantiate user client for updating workspace attributes
      user_client = user_fire_cloud_client(current_user, @user_workspace.namespace)
      # first, add submission to list of 'deleted_submissions' in workspace attributes (will hide submission in list)
      workspace = user_client.get_workspace(@user_workspace.namespace, @user_workspace.name)
      ws_attributes = workspace['workspace']['attributes']
      if ws_attributes['deleted_submissions'].blank?
        ws_attributes['deleted_submissions'] = [params[:submission_id]]
      else
        ws_attributes['deleted_submissions']['items'] << params[:submission_id]
      end
      logger.info "Adding #{params[:submission_id]} to workspace delete_submissions attribute in #{@user_workspace.name}"
      user_client.set_workspace_attributes(@user_workspace.namespace, @user_workspace.name, ws_attributes)
      logger.info "Starting submission #{params[:submission_id]} deletion in #{@user_workspace.name}"
      # use GCS Admin client to get/delete files
      submission_files = ApplicationController.gcs_client.execute_gcloud_method(:get_workspace_files, @user_workspace.namespace,
                                                           @user_workspace.name, prefix: params[:submission_id])
      submission_files.each do |file|
        ApplicationController.gcs_client.execute_gcloud_method(:delete_workspace_file, @user_workspace.namespace,
                                          @user_workspace.name, file.name)
      end
      render '/user_workspaces/submissions/delete_submission_files'
    rescue => e
      logger.error "Unable to remove submission #{params[:submission_id]} files from #{@user_workspace.name} due to: #{e.message}"
      @alert = "Unable to delete the outputs for #{params[:submission_id]} due to the following error: #{e.message}"
      render '/user_workspaces/submissions/display_modal'
    end
  end

  # download an output file
  def download_benchmark_output
    if !ApplicationController.fire_cloud_client.services_available?('GoogleBuckets')
      head 503 and return
    end

    requested_file = ApplicationController.gcs_client.execute_gcloud_method(:get_workspace_file, @user_workspace.namespace,
                                                       @user_workspace.name, params[:filename])
    if requested_file.present?
      @signed_url = ApplicationController.gcs_client.execute_gcloud_method(:generate_signed_url, @user_workspace.namespace,
                                                      @user_workspace.name, params[:filename], expires: 15)
      redirect_to @signed_url
    else
      redirect_to user_workspace_path(project: @user_workspace.namespace, name: @user_workspace.name),
                  alert: 'The file you requested was unavailable.  Please try again.' and return
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
    if @user_workspace.nil?
      redirect_to user_workspaces_path, alert: 'The requested workspace was not found' and return
    end
  end

  def set_user_projects
    @projects = Project.owned_by(current_user)
  end

  def set_reference_analysis
    @reference_analysis = ReferenceAnalysis.find(params[:reference_analysis_id])
  end

  def set_user_analysis
    @user_analysis = @user_workspace.user_analysis
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def user_workspace_params
    params.require(:user_workspace).permit(:name, :project_id, :user_id, :reference_analysis_id)
  end

  def user_analysis_params
    params.require(:user_analysis).permit(:name, :user_id, :user_workspace_id, :namespace, :snapshot, :wdl_contents)
  end

  # helper to redact a workflow on error
  def redact_workflow(user, namespace, name, snapshot)
    full_name = [namespace, name, snapshot].join('/')
    begin
      logger.info "Redacting workflow #{full_name}"
      user_fire_cloud_client(user).delete_method(namespace, name, snapshot.to_i)
      logger.info "Redaction complete for #{full_name}"
    rescue => e
      logger.error "Unable to redact #{full_name} due to error: #{e.message}"
    end
  end

  # load submissions for a user_workspace
  def load_valid_submissions
    @submissions = []
    begin
      user_client = user_fire_cloud_client(current_user)
      workspace = user_client.get_workspace(@user_workspace.namespace, @user_workspace.name)
      @submissions = user_client.get_workspace_submissions(@user_workspace.namespace, @user_workspace.name)
      # remove deleted submissions from list of runs
      if !workspace['workspace']['attributes']['deleted_submissions'].blank?
        deleted_submissions = workspace['workspace']['attributes']['deleted_submissions']['items']
        @submissions.delete_if {|submission| deleted_submissions.include?(submission['submissionId'])}
      end
    rescue => e
      logger.info "Cannot retrieve submissions for user_workspace '#{@user_workspace.full_name}': #{e.message}"
    end
  end
end
