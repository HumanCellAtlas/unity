require 'test_helper'

class AdminConfigurationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin_configuration = admin_configurations(:one)
    @user = User.first
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
                                                                           :provider => 'google_oauth2',
                                                                           :uid => '123545',
                                                                           :email => 'unity-admin@broadinstitute.org'
                                                                       })
    sign_in @user
  end

  test "should get index" do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    get admin_configurations_url
    assert_response :success
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test "should get new" do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    get new_admin_configuration_url
    assert_response :success
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test "should create admin_configuration" do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    assert_difference('AdminConfiguration.count') do
      post admin_configurations_url, params: { admin_configuration: { config_type: 'Reference Data Workspace', value: 'some-other-workspace', value_type: 'String' } }
    end

    assert_redirected_to admin_configurations_url
    assert AdminConfiguration.count == 3, 'Did not create new admin_configuration'
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test "should show admin_configuration" do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    get admin_configuration_url(@admin_configuration)
    assert_response :success
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test "should get edit" do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    get edit_admin_configuration_url(@admin_configuration)
    assert_response :success
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test "should update admin_configuration" do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    patch admin_configuration_url(@admin_configuration), params: { admin_configuration: { config_type: @admin_configuration.config_type, value: @admin_configuration.value, value_type: @admin_configuration.value_type } }
    assert_redirected_to admin_configurations_url
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test "should destroy admin_configuration" do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    assert_difference('AdminConfiguration.count', -1) do
      delete admin_configuration_url(@admin_configuration)
    end

    assert_redirected_to admin_configurations_url
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end
