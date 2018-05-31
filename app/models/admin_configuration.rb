class AdminConfiguration < ApplicationRecord

  attribute :config_type, :string
  attribute :value_type, :string, default: 'String'
  attribute :value, :string
  has_many :configuration_options, dependent: :destroy

  accepts_nested_attributes_for :configuration_options, reject_if: proc {|attributes| attributes['name'].blank? || attributes['value'].blank?}

  validates_presence_of :config_type, :value_type, :value
  validates_uniqueness_of :value, scope: [:config_type, :value_type]

  validate :validate_value_by_type

  API_NOTIFIER_NAME = 'API Health Check Notifier'
  FIRECLOUD_ACCESS_NAME = 'FireCloud Access'
  CONFIG_TYPES = ['Workflow Name', 'Unity FireCloud User Group', 'Reference Data Workspace', 'Unity FireCloud Project', API_NOTIFIER_NAME]
  VALUE_TYPES = %w(Numeric Boolean String)

  # display name for use in notices/alerts
  def display_name
    [self.config_type, self.value].join(': ')
  end

  # converter to return requested value as an instance of its value type
  # numerics will return an interger or float depending on value contents (also understands Rails shorthands for byte size increments)
  # booleans return true/false based on matching a variety of possible 'true' values
  # strings just return themselves
  def convert_value_by_type
    case self.value_type
      when 'Numeric'
        self.value.include?('.') ? self.value.to_f : self.value.to_i
      when 'Boolean'
        return self.value == '1'
      else
        return self.value
    end
  end

  def self.current_firecloud_access
    status = AdminConfiguration.find_by(config_type: AdminConfiguration::FIRECLOUD_ACCESS_NAME)
    if status.nil?
      'on'
    else
      status.value
    end
  end

  def self.firecloud_access_enabled?
    status = AdminConfiguration.find_by(config_type: AdminConfiguration::FIRECLOUD_ACCESS_NAME)
    if status.nil?
      true
    else
      status.value == 'on'
    end
  end

  # method to be called from cron to check the health status of the FireCloud API and set access if an outage is detected
  def self.check_api_health
    notifier_config = AdminConfiguration.find_or_create_by(config_type: AdminConfiguration::API_NOTIFIER_NAME, value_type: 'Boolean')
    firecloud_access = AdminConfiguration.find_or_create_by(config_type: AdminConfiguration::FIRECLOUD_ACCESS_NAME, value_type: 'String')
    api_available = ApplicationController.fire_cloud_client.api_available?

    # gotcha for very first time this is ever called
    if firecloud_access.value.nil?
      firecloud_access.update(value: 'on')
    end

    if notifier_config.value.nil?
      notifier_config.update(value: 1)
    end

    # if api is down...
    if !api_available
      # if access is still enabled, set to local-off and send notification to admins (if enabled)
      if firecloud_access.value == 'on'
        Rails.logger.error "#{Time.now}: ALERT: FIRECLOUD API UNAVAILABLE -- setting FireCloud access to 'local-off'"
        firecloud_access.update(value: 'local-off')
        if notifier_config.value == '1'
          current_time = Time.now.strftime('%D %r')
          UnityMailer.admin_notification('ALERT: FIRECLOUD API UNAVAILABLE', nil, "<p>The FireCloud API was found to be unavailable at #{current_time}.  Access has been disabled locally until API access is manually turned back on or the next automatic check returns positive.").deliver_now
          notifier_config.update(value: '0')
        end
      end
      # if api is up...
    else
      if firecloud_access.value == 'local-off'
        # local-off is currently used exclusively for API outages, so if the API is up and the portal is set to local-off,
        # then we can assume that the portal was put in this mode by AdminConfiguration.check_api_health and should
        # automatically recover.  This will not affect disabling compute or all access settings.
        firecloud_access.update(value: 'on')
        if notifier_config.value == '0'
          current_time = Time.now.strftime('%D %r')
          UnityMailer.admin_notification('ALERT: FireCloud API recovery', nil, "<p>The FireCloud API has recovered as of #{current_time}.  Access has been automatically restored.").deliver_now
          notifier_config.update(value: '1')
        end
      end
    end
  end

  # getter to return all configuration options as a hash
  def options
    opts = {}
    self.configuration_options.each do |option|
      opts.merge!({option.name.to_sym => option.value})
    end
    opts
  end

  private

  def validate_value_by_type
    case self.value_type
      when 'Numeric'
        unless self.value.to_f >= 0
          errors.add(:value, 'must be greater than or equal to zero.  Please enter another value.')
        end
      else
        # for booleans, we use a select box so values are constrained.  for strings, any value is valid
        return true
    end
  end
end
