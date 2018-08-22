require 'rubygems'
require 'test/unit'
require 'selenium-webdriver'

##
#
# ui_test_helper.rb - test helper class with functions using in all Webdriver regression tests
# will work with any test suite in test/ui_regression (requires @driver & @wait objects to function properly)
#
##

# argument parser for each test suite; must be called manually, will not parse arguments automatically
# defined outside Test::Unit::TestCase class to be available before running tests
def parse_test_arguments(arguments)
  # defaults
  $user = `whoami`.strip
  $chromedriver_path = '/usr/local/bin/chromedriver'
  $test_email = ''
  $test_email_password = ''
  $order = 'defined'
  $download_dir = "/Users/#{$user}/Downloads"
  $portal_url = 'https://localhost'
  $env = 'development'
  $random_seed = SecureRandom.uuid
  $verbose = false

  # usage string for help message
  $usage = "ruby test/ui_test_suite.rb -- -c=/path/to/chromedriver -e=testing.email@gmail.com -p='testing_email_password' -o=order -d=/path/to/downloads -u=portal_url -E=environment -r=random_seed"

  # parse arguments and set values
  arguments.each do |arg|
    if arg =~ /\-c\=/
      $chromedriver_path = arg.gsub(/\-c\=/, '')
    elsif arg =~ /\-e\=/
      $test_email = arg.gsub(/\-e\=/, '')
    elsif arg =~ /\-p\=/
      $test_email_password = arg.gsub(/\-p\=/, '')
    elsif arg =~ /\-o\=/
      $order = arg.gsub(/\-o\=/, '').to_sym
    elsif arg =~ /\-d\=/
      $download_dir = arg.gsub(/\-d\=/, '')
    elsif arg =~ /\-u\=/
      $portal_url = arg.gsub(/\-u\=/, '')
    elsif arg =~ /\-E\=/
      $env = arg.gsub(/\-E\=/, '')
    elsif arg =~ /\-r\=/
      $random_seed = arg.gsub(/\-r\=/, '')
    elsif arg =~ /\-v/
      $verbose = true
    end
  end
end

class Test::Unit::TestCase

  # return true/false if element is present in DOM
  # will handle if element doesn't exist or if reference is stale due to race condition
  def element_present?(how, what)
    @driver.find_element(how, what)
    true
  rescue Selenium::WebDriver::Error::NoSuchElementError
    false
  rescue Selenium::WebDriver::Error::StaleElementReferenceError
    false
  end

  # return true/false if an element is displayed
  # will handle if element doesn't exist or if reference is stale due to race condition
  def element_visible?(how, what)
    @driver.find_element(how, what).displayed?
  rescue Selenium::WebDriver::Error::ElementNotVisibleError
    false
  rescue Selenium::WebDriver::Error::NoSuchElementError
    false
  rescue Selenium::WebDriver::Error::StaleElementReferenceError
    false
  end

  # explicit wait until requested page loads
  def wait_until_page_loads(path)
    @wait.until { @driver.current_url.chomp('/') == path } # remove traing slash
    @wait.until { @driver.execute_script('return PAGE_RENDERED;') == true }
    $verbose ? puts("#{path} successfully loaded") : nil
  end

  # wait until a specific modal has completed opening (will be once shown.bs.modal fires and OPEN_MODAL has a value)
  def wait_for_modal_open(id)
    # sanity check in case modal has already opened and closed - if no modal opens in 10 seconds then exit and continue
    i = 0
    while @driver.execute_script("return OPEN_MODAL") == ''
      if i == 30
        $verbose ? puts("Exiting wait_for_modal_open(#{id}) after 30 seconds - no modal open") : nil
        return true
      else
        sleep(1)
        i += 1
      end
    end
    $verbose ? puts("current open modal: #{@driver.execute_script("return OPEN_MODAL")}") : nil
    # need to wait until modal is in the page and has completed opening
    @wait.until {@driver.execute_script("return OPEN_MODAL") == id}
    $verbose ? puts("requested modal #{id} now open") : nil
    true
  end

  # method to close a bootstrap modal by id
  def close_modal(id)
    wait_for_modal_open(id)
    modal = @driver.find_element(:id, id)
    close_button = modal.find_element(:class, 'close')
    close_button.click
    $verbose ? puts("closing modal: #{id}") : nil
    # wait until OPEN_MODAL has been cleared (will reset on hidden.bs.modal event)
    @wait.until {@driver.execute_script("return OPEN_MODAL") == ''}
    $verbose ? puts("modal: #{id} closed") : nil
  end

  # wait until element is rendered and visible
  def wait_for_render(how, what)
    @wait.until {element_visible?(how, what)}
  end

  # scroll to section of page as needed
  def scroll_to(section)
    case section
      when :bottom
        @driver.execute_script('window.scrollBy(0,9999)')
      when :top
        @driver.execute_script('window.scrollBy(0,-9999)')
      else
        nil
    end
    sleep(1)
  end

  # helper to log into admin portion of site using supplied credentials
  # Will also approve terms if not accepted yet, waits for redirect back to site, and closes modal
  def login(email, password)
    login_link = @driver.find_element(:id, 'login-nav')
    login_link.click
    $verbose ? puts('logging in as ' + email) : nil
    # fill out login form
    complete_login_process(email, password)
    # wait for redirect to finish by checking for footer element
    @not_loaded = true
    while @not_loaded == true
      begin
        # we need to return the result of the script to store its value
        loaded = @driver.execute_script("return elementVisible('.footer')")
        if loaded == true
          @not_loaded = false
        end
        sleep(1)
      rescue Selenium::WebDriver::Error::UnknownError
        # check to make sure if we need to accept terms first to complete login
        if @driver.current_url.include?('https://accounts.google.com/signin/oauth/consent')
          $verbose ? puts('approving access') : nil
          approve = @driver.find_element(:id, 'submit_approve_access')
          @clickable = approve['disabled'].nil?
          while @clickable != true
            sleep(1)
            @clickable = @driver.find_element(:id, 'submit_approve_access')['disabled'].nil?
          end
          approve.click
          $verbose ? puts('access approved') : nil
        end
        sleep(1)
      end
    end
    @wait.until {@driver.execute_script("return PAGE_RENDERED;")}
    if element_present?(:id, 'message_modal') && element_visible?(:id, 'message_modal')
      close_modal('message_modal')
    end
    $verbose ? puts('login successful') : nil
  end

  # method to log out of google so that we can log in with a different account
  def login_as_other(email, password)
    invalidate_google_session
    @driver.get @base_url
    login_link = @driver.find_element(:id, 'login-nav')
    login_link.click
    $verbose ? puts('logging in as ' + email) : nil
    use_new = @driver.find_element(:id, 'identifierLink')
    use_new.click
    wait_for_render(:id, 'identifierId')
    sleep(1)
    # fill out login form
    complete_login_process(email, password)
    # wait for redirect to finish by checking for footer element
    @not_loaded = true
    while @not_loaded == true
      begin
        # we need to return the result of the script to store its value
        loaded = @driver.execute_script("return elementVisible('.footer')")
        if loaded == true
          @not_loaded = false
        end
        sleep(1)
      rescue Selenium::WebDriver::Error::UnknownError
        # check to make sure if we need to accept terms first to complete login
        if @driver.current_url.include?('https://accounts.google.com/signin/oauth/consent')
          $verbose ? puts('approving access') : nil
          approve = @driver.find_element(:id, 'submit_approve_access')
          @clickable = approve['disabled'].nil?
          while @clickable != true
            sleep(1)
            @clickable = @driver.find_element(:id, 'submit_approve_access')['disabled'].nil?
          end
          approve.click
          $verbose ? puts('access approved') : nil
        end
        sleep(1)
      end
    end
    if element_present?(:id, 'message_modal') && element_visible?(:id, 'message_modal')
      close_modal('message_modal')
    end
    $verbose ? puts('login successful') : nil
  end

  # method to log out of portal (not Google)
  def logout_from_portal
    profile = @driver.find_element(:id, 'profile-nav')
    profile.click
    logout = @driver.find_element(:id, 'logout-nav')
    logout.click
    wait_until_page_loads(@base_url)
    close_modal('message_modal')
  end

  # method to log out of Google and portal
  def invalidate_google_session
    # check if driver was instantiated to suppress spurious errors when aborting/cancelling tests
    unless @driver.nil?
      @driver.get 'https://accounts.google.com/Logout'
      sleep(1)
    end
  end

  # helper to open tabs in front end, allowing time for tab to become visible
  def open_ui_tab(target)
    tab = @driver.find_element(:id, "#{target}-nav")
    tab.click
    @wait.until {@driver.find_element(:id, target).displayed?}
  end

  # open a new browser tab, switch to it and navigate to a url
  def open_new_page(url)
    $verbose ? puts("opening new page: #{url}") : nil
    @driver.execute_script('window.open()')
    @driver.switch_to.window(@driver.window_handles.last)
    sleep(1)
    @driver.get(url)
  end

  # accept an open alert with error handling
  def accept_alert
    $verbose ? puts('accepting alert') : nil
    open = false
    i = 1
    while !open
      if i <= 5
        begin
          @driver.switch_to.alert.accept
          open = true
        rescue Selenium::WebDriver::Error::NoSuchAlertError
          sleep 1
          i += 1
        end
      else
        raise Selenium::WebDriver::Error::TimeOutError, "Timing out on closing alert"
      end
    end
  end

  # load file either in browser or download and check for existence
  def download_file(link, basename)
    link.click
    if @driver.current_url.include?('https://storage.googleapis.com/')
      assert @driver.current_url =~ /#{basename}/, "Downloaded file url incorrect, did not find #{basename}"
      @driver.navigate.back
    else
      # give browser 5 seconds to initiate download
      sleep(5)
      # make sure file was actually downloaded
      file_exists = Dir.entries($download_dir).select {|f| f =~ /#{basename}/}.size >= 1 || File.exists?(File.join($download_dir, basename))
      assert file_exists, "did not find downloaded file: #{basename} in #{Dir.entries($download_dir).join(', ')}"

      # delete matching files
      Dir.glob("#{$download_dir}/*").select {|f| /#{basename}/.match(f)}.map {|f| File.delete(f)}
    end
  end

  private

  def complete_login_process(email, password)
    if !element_visible?(:id, 'identifierId')
      sleep 1
    end
    email_field = @driver.find_element(:id, 'identifierId')
    email_field.send_key(email)
    sleep(0.5) # this lets the animation complete
    if !element_visible?(:id, 'identifierNext')
      sleep 1
    end
    email_next = @driver.find_element(:id, 'identifierNext')
    email_next.click
    sleep(0.5) # this lets the animation complete
    if !element_visible?(:name, 'password')
      sleep 1
    end
    password_field = @driver.find_element(:name, 'password')
    password_field.send_key(password)
    sleep(0.5) # this lets the animation complete
    if !element_visible?(:id, 'passwordNext')
      sleep 1
    end
    password_next = @driver.find_element(:id, 'passwordNext')
    password_next.click
  end
end