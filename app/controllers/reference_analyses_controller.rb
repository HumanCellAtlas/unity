class ReferenceAnalysesController < ApplicationController
  before_action :authenticate_user!
  before_action :authenticate_admin
  before_action :set_reference_analysis, only: [:show, :edit, :update, :destroy, :populate_analysis_params]

  # GET /reference_analyses
  # GET /reference_analyses.json
  def index
    @reference_analyses = ReferenceAnalysis.all
  end

  # GET /reference_analyses/1
  # GET /reference_analyses/1.json
  def show
  end

  # GET /reference_analyses/new
  def new
    @reference_analysis = ReferenceAnalysis.new
  end

  # GET /reference_analyses/1/edit
  def edit
  end

  # POST /reference_analyses
  # POST /reference_analyses.json
  def create
    @reference_analysis = ReferenceAnalysis.new(reference_analysis_params)

    respond_to do |format|
      if @reference_analysis.save
        format.html { redirect_to reference_analysis_path(@reference_analysis), notice: "'#{@reference_analysis.display_name}' was successfully created." }
        format.json { render :show, status: :created, location: @reference_analysis }
      else
        format.html { render :new }
        format.json { render json: @reference_analysis.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /reference_analyses/1
  # PATCH/PUT /reference_analyses/1.json
  def update
    respond_to do |format|
      if @reference_analysis.update(reference_analysis_params)
        format.html { redirect_to reference_analysis_path(@reference_analysis), notice: "'#{@reference_analysis.display_name}' was successfully updated." }
        format.json { render :show, status: :ok, location: @reference_analysis }
      else
        format.html { render :edit }
        format.json { render json: @reference_analysis.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /reference_analyses/1
  # DELETE /reference_analyses/1.json
  def destroy
    display_name = @reference_analysis.display_name
    @reference_analysis.destroy
    respond_to do |format|
      format.html { redirect_to reference_analyses_path, notice: "'#{display_name}' was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_reference_analysis
      @reference_analysis = ReferenceAnalysis.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def reference_analysis_params
      params.require(:reference_analysis).permit(:firecloud_project, :firecloud_workspace, :analysis_wdl, :benchmark_wdl, :orchestration_wdl,
                                                 reference_analysis_data_attributes: [:id, :data_type, :call_name, :parameter_name, :parameter_value, :optional, :_destroy],
                                                 reference_analysis_options_attributes: [:id, :name, :value, :_destroy]

      )
    end
end
