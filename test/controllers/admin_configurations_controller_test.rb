require 'test_helper'

class AdminConfigurationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin_configuration = admin_configurations(:one)
  end

  test "should get index" do
    get admin_configurations_url
    assert_response :success
  end

  test "should get new" do
    get new_admin_configuration_url
    assert_response :success
  end

  test "should create admin_configuration" do
    assert_difference('AdminConfiguration.count') do
      post admin_configurations_url, params: { admin_configuration: { config_type: @admin_configuration.config_type, value: @admin_configuration.value, value_type: @admin_configuration.value_type } }
    end

    assert_redirected_to admin_configuration_url(AdminConfiguration.last)
  end

  test "should show admin_configuration" do
    get admin_configuration_url(@admin_configuration)
    assert_response :success
  end

  test "should get edit" do
    get edit_admin_configuration_url(@admin_configuration)
    assert_response :success
  end

  test "should update admin_configuration" do
    patch admin_configuration_url(@admin_configuration), params: { admin_configuration: { config_type: @admin_configuration.config_type, value: @admin_configuration.value, value_type: @admin_configuration.value_type } }
    assert_redirected_to admin_configuration_url(@admin_configuration)
  end

  test "should destroy admin_configuration" do
    assert_difference('AdminConfiguration.count', -1) do
      delete admin_configuration_url(@admin_configuration)
    end

    assert_redirected_to admin_configurations_url
  end
end
