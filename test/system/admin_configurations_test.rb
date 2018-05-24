require "application_system_test_case"

class AdminConfigurationsTest < ApplicationSystemTestCase
  setup do
    @admin_configuration = admin_configurations(:one)
  end

  test "visiting the index" do
    visit admin_configurations_url
    assert_selector "h1", text: "Admin Configurations"
  end

  test "creating a Admin configuration" do
    visit admin_configurations_url
    click_on "New Admin Configuration"

    fill_in "Config Type", with: @admin_configuration.config_type
    fill_in "Value", with: @admin_configuration.value
    fill_in "Value Type", with: @admin_configuration.value_type
    click_on "Create Admin configuration"

    assert_text "Admin configuration was successfully created"
    click_on "Back"
  end

  test "updating a Admin configuration" do
    visit admin_configurations_url
    click_on "Edit", match: :first

    fill_in "Config Type", with: @admin_configuration.config_type
    fill_in "Value", with: @admin_configuration.value
    fill_in "Value Type", with: @admin_configuration.value_type
    click_on "Update Admin configuration"

    assert_text "Admin configuration was successfully updated"
    click_on "Back"
  end

  test "destroying a Admin configuration" do
    visit admin_configurations_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Admin configuration was successfully destroyed"
  end
end
