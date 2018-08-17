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

  validate :validate_wdl_accessibility

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
end
