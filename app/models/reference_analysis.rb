class ReferenceAnalysis < ApplicationRecord
  attribute :firecloud_project, :string
  attribute :firecloud_workspace, :string
  attribute :analysis_wdl, :string
  attribute :benchmark_wdl, :string
  attribute :orchestration_wdl, :string

  validates_presence_of :firecloud_project, :firecloud_workspace, :analysis_wdl, :benchmark_wdl, :orchestration_wdl
  validates_uniqueness_of :firecloud_workspace, scope: [:firecloud_project]
  validates_format_of :firecloud_project, :firecloud_workspace, :analysis_wdl, :benchmark_wdl, :orchestration_wdl,
                      with: ALPHANUMERIC_EXTENDED, message: ALPHANUMERIC_EXTENDED_MESSAGE

  validate :reference_workspace_exists, on: :create, if: proc {|attributes| attributes.firecloud_project.present? && attributes.firecloud_workspace.present?}
  validate :set_reference_workspace_acls, on: :create
  validate :validate_wdl_accessibility, if: proc {|attributes| attributes.analysis_wdl.present? && attributes.benchmark_wdl.present? && attributes.orchestration_wdl.present?}
  validate :validate_wdl_configurations, if: proc {|attributes| attributes.orchestration_wdl.present?}

  belongs_to :user

  has_many :reference_analysis_data, dependent: :delete_all
  has_many :reference_analysis_options, dependent: :delete_all

  has_many :user_workspaces

  accepts_nested_attributes_for :reference_analysis_data, allow_destroy: true
  accepts_nested_attributes_for :reference_analysis_options, allow_destroy: true

  after_create :load_parameters_from_wdl!

  # combine firecloud_project & firecloud_workspace for use in generating URLs (via firecloud_link_for)
  def display_name
    "#{self.firecloud_project}/#{self.firecloud_workspace}"
  end

  # get the number of input/output settings by type
  def config_setting_count(data_type)
    self.reference_analysis_data.where(data_type: data_type).count
  end

  # populate inputs & outputs from reference analysis WDL definition.  will automatically fire after record creation
  # also clears out any previously saved inputs/outputs, so use with caution!
  def load_parameters_from_wdl!
    begin
      self.reference_analysis_data.delete_all
      wdl_namespace, wdl_name, wdl_version = extract_wdl_keys(:analysis_wdl)
      config = ApplicationController.fire_cloud_client.get_method_parameters(wdl_namespace, wdl_name, wdl_version.to_i)
      config.each do |data_type, settings|
        settings.each do |setting|
          vals = setting['name'].split('.')
          call_name = vals.shift
          parameter_name = vals.join('.')
          parameter_type = data_type == 'inputs' ? setting['inputType'] : setting['outputType']
          optional = setting['optional'] == true
          config_attr = {
              data_type: data_type,
              parameter_type: parameter_type,
              call_name: call_name,
              parameter_name: parameter_name,
              optional: optional
          }
          unless self.reference_analysis_data.where(config_attr).exists?
            self.reference_analysis_data.create!(config_attr)
          end
        end
      end
      true
    rescue => e
      Rails.logger.info "Error retrieving analysis WDL inputs/outputs: #{e.message}"
      e
    end
  end

  # get all configuration files for this analysis as a hash
  def configuration_settings
    settings = {}
    self.reference_analysis_data.each do |parameter|
      settings[parameter.data_type] ||= []
      config = {
          'name' => "#{parameter.call_name}.#{parameter.parameter_name}"
      }
      if parameter.data_type == 'inputs'
        config.merge!({
                          'optional' => parameter.optional,
                          'inputType' => parameter.parameter_type
                      })
      else
        config.merge!({'outputType' => parameter.parameter_type})
      end
      settings[parameter.data_type] << config
    end
    settings
  end

  # get require input configuration
  def required_inputs
    self.configuration_settings['inputs']
  end

  # get required output configuration
  def required_outputs
    self.configuration_settings['outputs']
  end

  # get key/value options pairs as hash
  def options
    opts = {}
    self.reference_analysis_options.each do |opt|
      opts.merge!({opt.name.to_sym => opt.value})
    end
    opts
  end

  # construct a WDL view URL based off of a WDL attribute
  def wdl_view_url(wdl_attr)
    wdl_namespace, wdl_name, wdl_version = extract_wdl_keys(wdl_attr)
    "https://portal.firecloud.org/#methods/#{wdl_namespace}/#{wdl_name}/#{wdl_version}/wdl"
  end

  # construct a GA4GH import URL based off of a WDL attribute
  def wdl_import_url(wdl_attr)
    wdl_namespace, wdl_name, wdl_version = extract_wdl_keys(wdl_attr)
    "https://api.firecloud.org/ga4gh/v1/tools/#{wdl_namespace}:#{wdl_name}/versions/#{wdl_version}/plain-WDL/descriptor"
  end

  # extract a WDL namespace, name, and snapshot from WDL value
  def extract_wdl_keys(wdl_attr)
    self.send(wdl_attr.to_sym).split('/')
  end

  private

  def reference_workspace_exists
    begin
      # if request succeeds, the the workspace is visible to unity
      ApplicationController.fire_cloud_client.get_workspace(self.firecloud_project, self.firecloud_workspace)
    rescue => e
      errors.add(:firecloud_workspace, "- The requested workspace of #{self.firecloud_project}/#{self.firecloud_workspace} was not found.  Please check again before continuing.")
    end
  end

  # set ACLs on reference workspace to allow service account & user group access
  def set_reference_workspace_acls
    begin
      # grant write access to service account, using user credentials
      user_client = FireCloudClient.new(self.user, self.firecloud_project)
      service_account_acl = user_client.create_workspace_acl(ApplicationController.fire_cloud_client.issuer, 'WRITER', true, false)
      service_account_share = user_client.update_workspace_acl(self.firecloud_project, self.firecloud_workspace, service_account_acl)
      added = service_account_share["usersUpdated"].first
      unless added['email'] == ApplicationController.fire_cloud_client.issuer && added['accessLevel'] == 'WRITER'
        errors.add(:base, "Adding write access to Unity service account failed; please try again.")
      end
      user_group = AdminConfiguration.find_by_config_type('Unity FireCloud User Group')
      unless user_group.present?
        errors.add(:base, "You must first create a user group with which to grant access to reference workspaces.  Please create and register one now.")
      end
      user_group_email = user_group.value + '@firecloud.org'
      # first check to see if share already exists
      current_acl = ApplicationController.fire_cloud_client.get_workspace_acl(self.firecloud_project, self.firecloud_workspace)
      current_group_share = current_acl['acl'][user_group_email]
      if current_group_share.nil? || current_group_share['accessLevel'] != 'READER'
        user_group_acl = ApplicationController.fire_cloud_client.create_workspace_acl(user_group_email, 'READER', false, false)
        add_share = ApplicationController.fire_cloud_client.update_workspace_acl(self.firecloud_project, self.firecloud_workspace, user_group_acl)
        added = add_share["usersUpdated"].first
        unless added['email'] == user_group_email && added['accessLevel'] == 'READER'
          errors.add(:base, "Adding read access to Unity User Group: #{user_group_email} failed; please try again.")
        end
      end
    rescue => e
      errors.add(:base, "Adding read access to Unity User Group: #{user_group_email} failed due to: #{e.message}.")
    end
  end

  # validate that a requested WDL is both accessible and readable
  def validate_wdl_accessibility
    [:analysis_wdl, :benchmark_wdl, :orchestration_wdl].each do |wdl_attr|
      if extract_wdl_keys(wdl_attr).size != 3
        errors.add(wdl_attr, "is not in the correct format.  The value for #{wdl_attr} must be in the form of :namespace/:name/:version")
      end
      wdl_namespace, wdl_name, wdl_version = extract_wdl_keys(wdl_attr)
      begin
        wdl = ApplicationController.fire_cloud_client.get_method(wdl_namespace, wdl_name, wdl_version)
        if !wdl['public']
          errors.add(wdl_attr, 'is not viewable by Unity.  Please make this WDL public before continuing.')
        end
      rescue => e
        errors.add(wdl_attr, 'is not viewable by Unity.  Please make this WDL public before continuing.')
      end
    end
  end

  # validate that a requested WDL has a valid configuration in the reference_analysis workspace
  def validate_wdl_configurations
    if extract_wdl_keys(:orchestration_wdl).size != 3
      errors.add(:orchestration_wdl, "is not in the correct format.  The value for this must be in the form of :namespace/:name/:version")
    end
    wdl_namespace, wdl_name, wdl_version = extract_wdl_keys(:orchestration_wdl)
    begin
      configurations = ApplicationController.fire_cloud_client.get_workspace_configurations(self.firecloud_project, self.firecloud_workspace)
      matching_config = configurations.find do |config|
        config['methodRepoMethod']['methodName'] == wdl_name &&
            config['methodRepoMethod']['methodNamespace'] == wdl_namespace &&
            config['methodRepoMethod']['methodVersion'] == wdl_version.to_i
      end

      if matching_config.nil?
        errors.add(:orchestration_wdl, "does not have a matching configuration saved in the workspace #{self.firecloud_project}/#{self.firecloud_workspace}")
      end
    rescue => e
      errors.add(:orchestration_wdl, "does not have a matching configuration saved in the workspace #{self.firecloud_project}/#{self.firecloud_workspace}")
    end
  end
end
