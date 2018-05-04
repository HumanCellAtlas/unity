require 'test_helper'

class SiteControllerTest < ActionDispatch::IntegrationTest
  test "should get hello_world" do
    get site_hello_world_url
    assert_response :success
  end

end
