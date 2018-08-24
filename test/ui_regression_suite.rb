require 'rubygems'
require 'test/unit'
require 'selenium-webdriver'
require File.expand_path('ui_test_helper.rb', 'test')

# UI regression suite that exercises functionality through simulating user interactions via Webdriver
#
# REQUIREMENTS
#
# This test suite must be run from outside of Docker (i.e. your host machine) as Docker cannot access localhost on your machine when running in linked container mode.
# Therefore, the following languages/packages must be installed on your host:
#
# 1. RVM (or equivalent Ruby language management system)
# 2. Ruby >= 2.5 (currently, 2.5.1 is the version running inside the container)
# 3. Gems: rubygems, test-unit, selenium-webdriver (see Gemfile.lock for version requirements)
# 4. Google Chrome
# 5. Chromedriver (https://sites.google.com/a/chromium.org/chromedriver/); make sure the verison you install works with your version of chrome
# 6. Register for FireCloud (https://portal.firecloud.org) for the Google account

# USAGE
#
# To run the test suite:
#
# ruby test/ui_test_suite.rb [-n /pattern/] [--ignore-name /pattern/] -- -c=/path/to/chromedriver -e=testing.email@gmail.com -p='testing_email_password' -o=order -d=/path/to/downloads -u=portal_url -E=environment -r=random_seed -v
#
# ui_test_suite.rb takes up to 10 arguments (2 are required):
# 1. path to your Chromedriver binary (passed with -c=)
# 2. path to your Chrome profile (passed with -C=): tests may fail to log in properly if you do not load the default chrome profile due to Google captchas
# 3. test email account (passed with -e=); REQUIRED. this must be a valid Google & FireCloud user and also configured as an 'admin' account in the portal
# 4. test email account password (passed with -p) REQUIRED. NOTE: you must quote the password to ensure it is passed correctly
# 5. test order (passed with -o=); defaults to defined order (can be alphabetic or random, but random will most likely fail horribly
# 6. download directory (passed with -d=); place where files are downloaded on your OS, defaults to standard OSX location (/Users/`whoami`/Downloads)
# 7. portal url (passed with -u=); url to point tests at, defaults to https://localhost
# 8. environment (passed with -E=); Rails environment that the target instance is running in.  Needed for constructing certain URLs
# 9. random seed (passed with -r=); random seed to use when running tests (will be needed if you're running front end tests against previously created studies from test suite)
# 10. verbose (passed with -v); run tests in verbose mode, will print extra logging messages where appropriate
#
# IMPORTANT: if you do not use -- before the argument list and give the appropriate flag (with =), it is processed as a Test::Unit flag and ignored, and likely may
# cause the suite to fail to launch.
#
# Tests are named using a tag-based system so that they can be run in smaller groups to only cover specific portions of site functionality.
# They can be run singly or in groups by passing -n /pattern/ before the -- on the command line.  This will run any tests that match
# the given regular expression.  You can run all 'front-end' and 'admin' tests this way (although front-end tests require the tests studies to have been created already)

# For instance, to run all the tests that cover user annotations:
#
# ruby ui_test_suite.rb -n /user-annotation/ -- [rest of arguments]
#
# To run a single test by name, pass -n 'test: [name of test]', e.g -n 'test: front-end: view: study'
#
# Similarly, you can run all test but exclude some by using --ignore-name /pattern/.  Also, you can combine -n and --ignore-name to run all matching
# test, excluding those matched by ignore-name.
#
# NOTE: when running this test harness, it tends to perform better on an external monitor.  Webdriver is very sensitive to elements not
# being clickable, and the more screen area available, the better.

## INITIALIZATION & CONFIGURATION

# parse arguments and set global variables
parse_test_arguments(ARGV)

# print configuration
puts "Chromedriver Binary: #{$chromedriver_path}"
puts "Testing email: #{$test_email}"
puts "Download directory: #{$download_dir}"
puts "Unity URL: #{$portal_url}"
puts "Environment: #{$env}"
puts "Random Seed: #{$random_seed}"
puts "Verbose: #{$verbose}"

# make sure download & chromedriver paths exist and portal url is valid, otherwise kill tests before running and print usage
if !File.exists?($chromedriver_path)
  puts "No Chromedriver binary found at #{$chromedriver_path}"
  puts $usage
  exit(1)
elsif !Dir.exists?($download_dir)
  puts "No download directory found at #{$download_dir}"
  puts $usage
  exit(1)
elsif !$portal_url.start_with?('https://')
  puts "Invalid portal url: #{$portal_url}; must begin with https://"
  puts $usage
  exit(1)
end

class UiRegressionSuite < Test::Unit::TestCase
  self.test_order = $order

  def setup
    # disable the 'save your password' prompt
    caps = Selenium::WebDriver::Remote::Capabilities.chrome("chromeOptions" => {'prefs' => {'credentials_enable_service' => false}})
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--incognito')
    @driver = Selenium::WebDriver::Driver.for :chrome, driver_path: $chromedriver_dir,
                                              options: options, desired_capabilities: caps,
                                              driver_opts: {log_path: '/tmp/webdriver.log'}
    @driver.manage.window.maximize
    @base_url = $portal_url
    @accept_next_alert = true
    @driver.manage.timeouts.implicit_wait = 15
    # only Google auth

    @wait = Selenium::WebDriver::Wait.new(:timeout => 30)
    @test_data_path = File.expand_path(File.join(File.dirname(__FILE__), 'test_data')) + '/'
    @base_path = File.expand_path(File.join(File.dirname(__FILE__), '..'))
    puts "\n"
  end

  # called on completion of every test (whether it passes or fails)
  def teardown
    invalidate_google_session
    @driver.quit
  end

  test 'load home page' do
    puts "#{File.basename(__FILE__)}: '#{self.method_name}'"

    @driver.get @base_url
    wait_until_page_loads(@base_url)
    assert @driver.current_url.chomp('/') == @base_url, "Did not load home page at #{@base_url}"
    assert element_present?(:id, 'main-jumbo'), "Did not find home page jumbotron"

    puts "#{File.basename(__FILE__)}: '#{self.method_name}' successful!"
  end

  test 'register a billing project' do
    puts "#{File.basename(__FILE__)}: '#{self.method_name}'"
    @driver.get @base_url
    login($test_email, $test_email_password)

    # go to my billing projects page
    profile_menu = @driver.find_element(:id, 'profile-nav')
    profile_menu.click
    billing_projects_nav = @driver.find_element(:id, 'billing-projects-nav')
    billing_projects_nav.click
    wait_until_page_loads(@base_url + '/projects')
    omit_if !datatable_empty?('projects'), "#{$test_email} already has a registered project" do
      # register an existing billing project
      register_existing = @driver.find_element(:id, 'register-existing-project')
      register_existing.click
      wait_until_page_loads(@base_url + '/projects/new')
      namespace_dropdown = @driver.find_element(:id, 'project_namespace')
      opts = namespace_dropdown.find_elements(:tag_name, 'option')
      namespace = opts.find {|opt| !opt.text.start_with?('Please select')}
      # skip if no projects are available
      omit_if namespace.nil?, "#{$test_email} has no available projects to use, skipping" do
        # select first available project and save
        namespace_dropdown.send_key namespace.text
        save_btn = @driver.find_element(:id, 'save-project')
        save_btn.click
        close_modal('notices-modal')
        # validate project saved, and look at workspaces detail
        assert element_present?(:id, 'project-users'), "Project record did not save correctly, did not find users table"
        workspaces_btn = @driver.find_element(:class, 'workspaces-btn')
        workspaces_btn.click
        assert element_present?(:id, 'workspaces'), "Project workspaces did not load correctly, did not find workspaces table"
      end
    end

    puts "#{File.basename(__FILE__)}: '#{self.method_name}' successful!"
  end

  test 'create a user benchmarking workspace' do
    puts "#{File.basename(__FILE__)}: '#{self.method_name}'"
    @driver.get @base_url
    login($test_email, $test_email_password)

    # benchmark first available analysis
    benchmark_analysis_link = @driver.find_element(:class, 'benchmark-reference-analysis')
    benchmark_analysis_link.click
    wait_for_render(:id, 'user_workspace_project_id')
    project_dropdown = @driver.find_element(:id, 'user_workspace_project_id')
    selected_project = project_dropdown.text
    omit_if selected_project.empty?, "#{$test_email} has no available projects" do
      name_field = @driver.find_element(:id, 'user_workspace_name')
      name_field.clear
      workspace_name = "test-benchmark-#{$random_seed}"
      name_field.send_keys(workspace_name)
      save_btn = @driver.find_element(:id, 'save-user-workspace')
      save_btn.click
      close_modal('notices-modal')
      assert element_present?(:id, 'user_analysis_name'), "Did not successfully create workspace, did not find user analysis form"
      # open FC workspace
      remote_workspace_btn = @driver.find_element(:id, 'view-user-workspace-remote')
      remote_workspace_btn.click
      @wait.until {@driver.current_url.start_with?('https://portal.firecloud.org')}
      assert element_present?(:class, 'fa-check-circle'), "FireCloud workspace did not provision correctly"
    end

    puts "#{File.basename(__FILE__)}: '#{self.method_name}' successful!"
  end

  test 'create a user analysis inside a benchmarking workspace' do
    puts "#{File.basename(__FILE__)}: '#{self.method_name}'"
    @driver.get @base_url
    login($test_email, $test_email_password)

    # load my-benchmarks
    profile_menu = @driver.find_element(:id, 'profile-nav')
    profile_menu.click
    benchmarks_nav = @driver.find_element(:id, 'user-workspaces-nav')
    benchmarks_nav.click
    wait_until_page_loads(@base_url + '/my-benchmarks')
    workspace_name = "test-benchmark-#{$random_seed}"
    workspace_url_link = @driver.find_element(:class, "view-#{workspace_name}")
    workspace_url = workspace_url_link['href']
    benchmark_btn = @driver.find_element(:class, "benchmark-#{workspace_name}")
    benchmark_btn.click
    wait_until_page_loads(workspace_url)
    analysis_name = "user-analysis-#{$random_seed}"
    name_field = @driver.find_element(:id, 'user_analysis_name')
    name_field.send_keys(analysis_name)
    # load reference analysis first
    load_ref_analysis_btn = @driver.find_element(:id, 'populate-reference-wdl')
    load_ref_analysis_btn.click
    @wait.until { @driver.execute_script("return $('#user_analysis_wdl_contents').data('has-wdl')") == true }
    user_analysis_wdl_contents = @driver.find_element(:id, 'user_analysis_wdl_contents')
    assert !user_analysis_wdl_contents['value'].empty?, "Did not populate wdl_contents with reference analysis"
    # supply user analysis
    wdl_payload = File.open(File.join(@test_data_path, 'wdl', 'test_analysis_good.wdl')).read
    user_analysis_wdl_contents.clear
    user_analysis_wdl_contents.send_keys(wdl_payload)
    updated_contents = @driver.find_element(:id, 'user_analysis_wdl_contents')['value']
    assert updated_contents == wdl_payload, "Updated WDL payload does not match supplied user WDL"
    save_analysis_btn = @driver.find_element(:id, 'save-user-analysis')
    save_analysis_btn.click
    close_modal('notices-modal')
    assert element_present?(:id, 'create-benchmark-analysis'), "User analysis did not save - benchmark submit button not present"
    # click back to user analysis tab and validate method saved by checking snapshot
    open_ui_tab('user-analysis')
    user_analysis_snapshot = @driver.find_element(:id, 'user_analysis_snapshot')['value']
    assert user_analysis_snapshot.to_i == 1, "Snapshot is incorrect; expected 1 but found #{user_analysis_snapshot}"

    puts "#{File.basename(__FILE__)}: '#{self.method_name}' successful!"
  end

  test 'submit a benchmarking analysis from a benchmarking workspace' do
    puts "#{File.basename(__FILE__)}: '#{self.method_name}'"
    @driver.get @base_url
    login($test_email, $test_email_password)

    # load my-benchmarks
    profile_menu = @driver.find_element(:id, 'profile-nav')
    profile_menu.click
    benchmarks_nav = @driver.find_element(:id, 'user-workspaces-nav')
    benchmarks_nav.click
    wait_until_page_loads(@base_url + '/my-benchmarks')
      workspace_name = "test-benchmark-#{$random_seed}"
      workspace_url_link = @driver.find_element(:class, "view-#{workspace_name}")
      workspace_url = workspace_url_link['href']
      benchmark_btn = @driver.find_element(:class, "benchmark-#{workspace_name}")
      benchmark_btn.click
      wait_until_page_loads(workspace_url)
      submit_benchmark_btn = @driver.find_element(:id, 'create-benchmark-analysis')
      submit_benchmark_btn.click
      close_modal('notices-modal')
      refresh_submissions_btn = @driver.find_element(:id, 'refresh-submissions-table')
      abort_btns = @driver.find_elements(:class, 'abort-submission')
      while abort_btns.empty?
        refresh_submissions_btn.click
        sleep(5)
        abort_btns = @driver.find_elements(:class, 'abort-submission')
      end
      # abort workflow=
      abort_btn = abort_btns.first
      abort_btn.click
      accept_alert
      close_modal('generic-update-modal')
      # submit again
      resubmit_btn = @driver.find_element(:class, 'benchmark-analysis-btn')
      resubmit_btn.click
      close_modal('notices-modal')
      # there should be two submissions in the table now
      submissions = @driver.find_elements(:class, 'benchmark-submission-entry')
      assert submissions.size == 2, "Did not find correct number of entries.  Expected 2 and found #{submissions.size}"

    puts "#{File.basename(__FILE__)}: '#{self.method_name}' successful!"
  end

  test 'load benchmarking submission outputs' do
    puts "#{File.basename(__FILE__)}: '#{self.method_name}'"

    @driver.get @base_url
    login($test_email, $test_email_password)

    # load benchmarking workspace
    profile_menu = @driver.find_element(:id, 'profile-nav')
    profile_menu.click
    benchmarks_nav = @driver.find_element(:id, 'user-workspaces-nav')
    benchmarks_nav.click
    wait_until_page_loads(@base_url + '/my-benchmarks')
    workspace_name = "test-benchmark-#{$random_seed}"
    workspace_url_link = @driver.find_element(:class, "view-#{workspace_name}")
    workspace_url = workspace_url_link['href']
    benchmark_btn = @driver.find_element(:class, "benchmark-#{workspace_name}")
    benchmark_btn.click
    wait_until_page_loads(workspace_url)

    # wait for submission to complete
    submissions_table = @driver.find_element(:id, 'submissions-table')
    submissions = submissions_table.find_element(:tag_name, 'tbody').find_elements(:tag_name, 'tr')
    completed_submission = submissions.find {|sub|
      sub.find_element(:class, "submission-state").text == 'Done' &&
          sub.find_element(:class, "submission-status").text == 'Succeeded'
    }
    i = 1
    while completed_submission.nil?
      omit_if i >= 60, 'Skipping test; waited 5 minutes but no submissions complete yet.'

      $verbose ? puts("no completed submissions, refresh try ##{i}") : nil
      refresh_btn = @driver.find_element(:id, 'refresh-submissions-table-top')
      refresh_btn.click
      sleep 5
      submissions_table = @driver.find_element(:id, 'submissions-table')
      submissions = submissions_table.find_element(:tag_name, 'tbody').find_elements(:tag_name, 'tr')
      completed_submission = submissions.find {|sub|
        sub.find_element(:class, "submission-state").text == 'Done' &&
            sub.find_element(:class, "submission-status").text == 'Succeeded'
      }
      i += 1
    end
    output_btn = @driver.find_element(:class, 'get-submission-outputs')
    output_btn.click
    wait_for_modal_open('generic-update-modal')
    submission_outputs = @driver.find_elements(:class, 'submission-output')
    assert submission_outputs.any?, "Did not find any submission outputs"
    output_file = submission_outputs.sample
    output_file.click
    @wait.until { !@driver.current_url.include?(@base_url) }
    assert @driver.current_url.include?('apidata.googleusercontent.com'), "Did not load submission output file"
    assert @driver.find_element(:tag_name, 'body').text.include?('Wrote qc matrix'), "Did not find expected string in file contents"

    puts "#{File.basename(__FILE__)}: '#{self.method_name}' successful!"
  end

  test 'delete benchmarking workspace submissions' do
    puts "#{File.basename(__FILE__)}: '#{self.method_name}'"

    @driver.get @base_url
    login($test_email, $test_email_password)

    profile_menu = @driver.find_element(:id, 'profile-nav')
    profile_menu.click
    benchmarks_nav = @driver.find_element(:id, 'user-workspaces-nav')
    benchmarks_nav.click
    wait_until_page_loads(@base_url + '/my-benchmarks')
    workspace_name = "test-benchmark-#{$random_seed}"
    workspace_url_link = @driver.find_element(:class, "view-#{workspace_name}")
    workspace_url = workspace_url_link['href']
    benchmark_btn = @driver.find_element(:class, "benchmark-#{workspace_name}")
    benchmark_btn.click
    wait_until_page_loads(workspace_url)

    submissions_table = @driver.find_element(:id, 'submissions-table')
    submissions = submissions_table.find_element(:tag_name, 'tbody').find_elements(:tag_name, 'tr')

    # delete a submission
    delete_btns = @driver.find_elements(:class, 'delete-submission-files')
    btn = delete_btns.sample
    btn.click
    accept_alert
    close_modal('generic-update-modal')
    updated_submissions = submissions_table.find_element(:tag_name, 'tbody').find_elements(:tag_name, 'tr')
    assert updated_submissions.size == submissions.size - 1, "Did not delete workspace submission, expected #{submissions.size - 1} remaining submission but found #{updated_submissions.size}"

    puts "#{File.basename(__FILE__)}: '#{self.method_name}' successful!"
  end

  test 'delete benchmarking workspace' do
    puts "#{File.basename(__FILE__)}: '#{self.method_name}'"

    @driver.get @base_url
    login($test_email, $test_email_password)

    profile_menu = @driver.find_element(:id, 'profile-nav')
    profile_menu.click
    benchmarks_nav = @driver.find_element(:id, 'user-workspaces-nav')
    benchmarks_nav.click
    wait_until_page_loads(@base_url + '/my-benchmarks')
    workspace_name = "test-benchmark-#{$random_seed}"
    workspace_url_link = @driver.find_element(:class, "view-#{workspace_name}")
    workspace_url = workspace_url_link['href']
    benchmark_btn = @driver.find_element(:class, "benchmark-#{workspace_name}")
    benchmark_btn.click
    wait_until_page_loads(workspace_url)

    # open FC workspace
    remote_workspace_btn = @driver.find_element(:id, 'view-user-workspace-remote')
    remote_workspace_btn.click
    @wait.until {@driver.current_url.starts_with?('https://portal.firecloud.org')}
    fc_workspace_url = @driver.current_url
    @driver.get @base_url + '/my-benchmarks'
    delete_btn = @driver.find_element(:class, "delete-user-workspace-#{workspace_name}")
    delete_btn.click
    accept_alert
    close_modal('notices-modal')
    assert datatable_empty?('my-benchmarks'), "Did not successfully delete benchmarking workspace: table is not empty"
    @driver.get fc_workspace_url
    assert @driver.find_element(:xpath, "//div[@data-test-id='no-bucket-access']").displayed?, "Did not find bucket deletion message"

    puts "#{File.basename(__FILE__)}: '#{self.method_name}' successful!"
  end

  test 'remove registered projects' do
    puts "#{File.basename(__FILE__)}: '#{self.method_name}'"
    @driver.get @base_url
    login($test_email, $test_email_password)

    # go to my billing projects page
    profile_menu = @driver.find_element(:id, 'profile-nav')
    profile_menu.click
    billing_projects_nav = @driver.find_element(:id, 'billing-projects-nav')
    billing_projects_nav.click
    wait_until_page_loads(@base_url + '/projects')
    omit_if datatable_empty?('projects') do
      delete_btn = @driver.find_element(:class, 'delete-project-btn')
      delete_btn.click
      accept_alert
      close_modal('notices-modal')
    end
    assert datatable_empty?('projects'), "Did not remove project, table is not empty: #{datatable_empty?('projects')}"
  end

end