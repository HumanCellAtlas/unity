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

  # combine firecloud_project & firecloud_workspace for use in generating URLs (via firecloud_link_for)
  def display_name
    "#{self.firecloud_project}/#{self.firecloud_workspace}"
  end

  # get the number of input/output settings by type
  def config_setting_count(data_type)
    self.reference_analysis_data.where(data_type: data_type).count
  end

  # get all configuration files for this analysis as a hash
  def configuration_settings
    settings = {}
    self.reference_analysis_data.each do |parameter|
      settings[parameter.data_type.to_sym] ||= {}
      settings[parameter.data_type.to_sym][parameter.call_name.to_sym] ||= {}
      settings[parameter.data_type.to_sym][parameter.call_name.to_sym].merge!({parameter.parameter_name.to_sym => parameter.parameter_value})
    end
    settings
  end

  # get a list of all call names for this reference analysis by data_type, or all (default)
  def call_names(data_type=nil)
    data = data_type.present? ? self.reference_analysis_data.where(data_type: data_type) : self.reference_analysis_data
    data.map(&:call_name).uniq
  end

  # get require input configuration
  def required_inputs
    self.configuration_settings[:input]
  end

  # get required output configuration
  def required_outputs
    self.configuration_settings[:output]
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
