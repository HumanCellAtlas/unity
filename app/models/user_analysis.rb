class UserAnalysis < ApplicationRecord

  belongs_to :user_workspace
  belongs_to :user

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
    reference_analysis_config = self.user_workspace.reference_analysis.configuration_settings
    user_config = self.configuration_settings
    Rails.logger.info "Validating user_analysis #{self.full_name} inputs/outputs"
    unless user_config == reference_analysis_config
      # redact this wdl so there are no orphans
      user_client = FireCloudClient.new(self.user)
      user_client.delete_method(self.namespace, self.name, self.snapshot)
      errors.add(:wdl_contents, "do not match the reference analysis workflow input/output parameters. " +
          "Please refer to #{self.user_workspace.reference_analysis.wdl_view_url(:analysis_wdl)} for more information.")
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
