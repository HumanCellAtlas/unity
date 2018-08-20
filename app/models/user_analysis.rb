class UserAnalysis < ApplicationRecord

  belongs_to :user_workspace
  belongs_to :user
  has_many :benchmark_analyses, dependent: :destroy

  attribute :namespace, :string
  attribute :name, :string
  attribute :snapshot, :integer
  attribute :wdl_contents, :text

  validates_presence_of :namespace, :name, :wdl_contents
  validates_format_of :namespace, :name, with: ALPHANUMERIC_EXTENDED, message: ALPHANUMERIC_EXTENDED_MESSAGE
  validate :add_method_to_repository, on: [:create, :update]
  validate :validate_required_parameters, on: [:create, :update]
  validates_uniqueness_of :snapshot, scope: [:namespace, :name]
  before_destroy :remove_method_from_repository

  def default_namespace
    self.user_workspace.name + '-analysis'
  end
  
  def full_name
    "#{self.namespace}/#{self.name}/#{self.snapshot}"
  end

  # name as DOM element ID
  def full_name_as_id
    self.full_name.gsub(/\//, '-')
  end

  # return reference_analysis associated with this analysis
  def reference_analysis
    self.user_workspace.reference_analysis
  end

  # get workflow inputs/ouputs from Methods Repo
  def configuration_settings
    begin
      user_client = FireCloudClient.new(self.user)
      user_client.get_method_parameters(self.namespace, self.name, self.snapshot)
    rescue => e
      Rails.logger.info "Error retrieving user analysis WDL inputs/outputs: #{e.message}"
      {error: e.message}
    end
  end

  # construct a WDL view URL to point to methods repo
  def wdl_view_url
    "https://portal.firecloud.org/#methods/#{self.namespace}/#{self.name}/#{self.snapshot}/wdl"
  end

  # construct a GA4GH import URL
  def wdl_import_url
    "https://api.firecloud.org/ga4gh/v1/tools/#{self.namespace}:#{self.name}/versions/#{self.snapshot}/plain-WDL/descriptor"
  end

  def orchestration_name
    self.name + '-orchestration'
  end

  # construct and import a new user_analysis specific WDL into the methods repo to benchmark against this reference_analysis
  def create_orchestration_from_self
    begin
      Rails.logger.info "Creating custom orchestration WDL for #{self.full_name}"
      # get orchestration WDL contents
      orchestration_namespace, orchestration_name, orchestration_snapshot = self.reference_analysis.extract_wdl_keys(:orchestration_wdl)
      orchestration_wdl = ApplicationController.fire_cloud_client.get_method(orchestration_namespace, orchestration_name,
                                                                             orchestration_snapshot.to_i)
      orchestration_wdl_contents = orchestration_wdl.split("\n")
      # find the original analysis_wdl import and replace with user_analyis.wdl_import_url
      analysis_index = orchestration_wdl_contents.index {|import| import =~ /#{self.reference_analysis.wdl_import_url(:analysis_wdl)}/}
      reformatted_import = orchestration_wdl_contents[analysis_index].gsub(/#{self.reference_analysis.wdl_import_url(:analysis_wdl)}/,
                                                                           "#{self.wdl_import_url}")
      orchestration_wdl_contents[analysis_index] = reformatted_import
      # add method to FireCloud Methods Repo
      new_method_name = self.orchestration_name
      synopsis = "Custom orchestration for #{self.name}"
      Rails.logger.info "Importing #{self.namespace}/#{new_method_name} into methods repo"
      user_client = FireCloudClient.new(self.user)
      updated_orchestration = user_client.create_method(self.namespace, new_method_name, synopsis, orchestration_wdl_contents.join("\n"))
      Rails.logger.info "Import of #{updated_orchestration['namespace']}/#{updated_orchestration['name']}/#{updated_orchestration['snapshotId']} successful"
      updated_orchestration
    rescue => e
      Rails.logger.error "Unable to create custom orchestration WDL for #{self.full_name}: #{e.message}"
      e.message
    end
  end

  # create a configuration object to run this user_analysis in a benchmark submission
  def create_orchestration_configuration(custom_orchestration)
    begin
      orchestration_namespace, orchestration_name, orchestration_snapshot = self.reference_analysis.extract_wdl_keys(:orchestration_wdl)
      user_client = FireCloudClient.new(self.user)
      workspace_configs = user_client.get_workspace_configurations(self.user_workspace.namespace, self.user_workspace.name)
      orchestration_config = workspace_configs.find do |config|
          config['methodRepoMethod']['methodName'] == orchestration_name &&
          config['methodRepoMethod']['methodNamespace'] == orchestration_namespace &&
          config['methodRepoMethod']['methodVersion'] == orchestration_snapshot.to_i
      end
      if orchestration_config.present?
        # now set configuration method to use newly created custom orchestration WDL
        # if the user_analysis is valid, then the inputs/outputs match the existing reference_analysis and the config is valid
        orchestration_config['methodRepoMethod']['methodName'] = custom_orchestration['name']
        orchestration_config['methodRepoMethod']['methodNamespace'] = custom_orchestration['namespace']
        orchestration_config['methodRepoMethod']['methodVersion'] = custom_orchestration['snapshotId']
        orchestration_config['namespace'] = self.namespace
        orchestration_config['name'] = self.orchestration_name
        new_workspace_config = user_client.create_workspace_configuration(self.user_workspace.namespace,
                                                                    self.user_workspace.name, orchestration_config)
        new_workspace_config
      else
        raise RuntimeError.new "orchestration config not found for #{self.reference_analysis.orchestration_wdl}"
      end
    rescue => e
      Rails.logger.error "Unable to create custom orchestration config for #{self.full_name} due to an error: #{e.message}"
      e.message
    end
  end

  private

  # add user_analysis to methods repository and set ACL to public read
  def add_method_to_repository
    begin
      Rails.logger.info "Adding #{self.namespace}/#{self.name} to methods repo as new snapshot"
      user_client = FireCloudClient.new(self.user)
      synopsis = "User analysis for #{self.user_workspace.name}"
      remote_method = user_client.create_method(self.namespace, self.name, synopsis, self.wdl_contents)
      if remote_method.present?
        self.snapshot = remote_method['snapshotId']
      else
        errors.add(:wdl_contents, '- did not successfully add to methods repo (no snapshot assigned).  Please try again.')
      end
      Rails.logger.info "#{self.full_name} successfully added to methods repo"
      Rails.logger.info "Setting permissions to allow imports for #{self.full_name}"
      public_acl = user_client.create_method_acl('public', 'READER')
      updated_acl = user_client.update_method_permissions(self.namespace, self.name, self.snapshot, public_acl)
      public_added = updated_acl.detect {|acl| acl['user'] == 'public' && acl['role'] == 'READER'}
      unless public_added.present?
        user_client.delete_method(self.namespace, self.name, self.snapshot)
        errors.add(:wdl_contents, '- did not successfully set permissions on method (not publicly readable).  Please try again.')
      end
      Rails.logger.info "Public access set on #{self.full_name}"
    rescue => e
      Rails.logger.error "Unable to add #{self.full_name} to methods repo: #{e.message}"
      errors.add(:wdl_contents, "- unable to add this analysis to the methods repo due to an error: #{e.message}")
    end
  end

  # validate that this method has the correct required input/output parameters to work with the orchestration WDL
  def validate_required_parameters
    reference_analysis_config = self.reference_analysis.configuration_settings
    user_config = self.configuration_settings
    Rails.logger.info "Validating user_analysis #{self.full_name} inputs/outputs"
    unless user_config == reference_analysis_config
      # redact this wdl so there are no orphans
      user_client = FireCloudClient.new(self.user)
      user_client.delete_method(self.namespace, self.name, self.snapshot)
      errors.add(:wdl_contents, "do not match the reference analysis workflow input/output parameters. " +
          "Please refer to #{self.reference_analysis.wdl_view_url(:analysis_wdl)} for more information.")
    end
  end

  # redact all versions of this user-supplied analysis from the methods repo
  def remove_method_from_repository
    begin
      user_client = FireCloudClient.new(self.user)
      max_snapshot = self.snapshot
      max_snapshot.downto(1) do |version|
        Rails.logger.info "Redacting #{self.full_name}/#{version} from methods repo"
        user_client.delete_method(self.namespace, self.name, version)
        Rails.logger.info "#{self.full_name}/#{version} successfully redacted from methods repo"
      end
    rescue => e
      Rails.logger.error "Unable to redact #{self.full_name} to methods repo: #{e.message}"
    end
  end
end
