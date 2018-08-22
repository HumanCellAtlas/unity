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

end