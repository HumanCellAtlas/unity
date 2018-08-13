require 'test_helper'

class ReferenceAnalysesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @reference_analysis = reference_analyses(:one)
  end

  test "should get index" do
    get reference_analyses_url
    assert_response :success
  end

  test "should get new" do
    get new_reference_analysis_url
    assert_response :success
  end

  test "should create reference_analysis" do
    assert_difference('ReferenceAnalysis.count') do
      post reference_analyses_url, params: { reference_analysis: { analysis_wdl: @reference_analysis.analysis_wdl, benchmark_wdl: @reference_analysis.benchmark_wdl, firecloud_project: @reference_analysis.firecloud_project, firecloud_workspace: @reference_analysis.firecloud_workspace, orchestration_wdl: @reference_analysis.orchestration_wdl } }
    end

    assert_redirected_to reference_analysis_url(ReferenceAnalysis.last)
  end

  test "should show reference_analysis" do
    get reference_analysis_url(@reference_analysis)
    assert_response :success
  end

  test "should get edit" do
    get edit_reference_analysis_url(@reference_analysis)
    assert_response :success
  end

  test "should update reference_analysis" do
    patch reference_analysis_url(@reference_analysis), params: { reference_analysis: { analysis_wdl: @reference_analysis.analysis_wdl, benchmark_wdl: @reference_analysis.benchmark_wdl, firecloud_project: @reference_analysis.firecloud_project, firecloud_workspace: @reference_analysis.firecloud_workspace, orchestration_wdl: @reference_analysis.orchestration_wdl } }
    assert_redirected_to reference_analysis_url(@reference_analysis)
  end

  test "should destroy reference_analysis" do
    assert_difference('ReferenceAnalysis.count', -1) do
      delete reference_analysis_url(@reference_analysis)
    end

    assert_redirected_to reference_analyses_url
  end
end
