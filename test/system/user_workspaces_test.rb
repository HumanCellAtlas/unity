require "application_system_test_case"

class UserWorkspacesTest < ApplicationSystemTestCase
  setup do
    @user_workspace = user_workspaces(:one)
  end

  test "visiting the index" do
    visit user_workspaces_url
    assert_selector "h1", text: "User Workspaces"
  end

  test "creating a User workspace" do
    visit user_workspaces_url
    click_on "New User Workspace"

    click_on "Create User workspace"

    assert_text "User workspace was successfully created"
    click_on "Back"
  end

  test "updating a User workspace" do
    visit user_workspaces_url
    click_on "Edit", match: :first

    click_on "Update User workspace"

    assert_text "User workspace was successfully updated"
    click_on "Back"
  end

  test "destroying a User workspace" do
    visit user_workspaces_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "User workspace was successfully destroyed"
  end
end
