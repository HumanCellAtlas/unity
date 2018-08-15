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
  validates_uniqueness_of :snapshot, scope: [:namespace, :name]
  before_destroy :remove_method_from_repository

  def default_namespace
    self.user_workspace.name + '-analysis'
  end
  
  def full_name
    "#{self.namespace}/#{self.name}/#{self.snapshot}"
  end

  def full_name_as_id
    self.full_name.gsub(/\//, '-')
  end

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
      updated_acl = user_client.update_method_acl(self.namespace, self.name, self.snapshot, public_acl)
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

  private

  def remove_method_from_repository
    begin
      Rails.logger.info "Redacting #{self.full_name} from methods repo"
      user_client = FireCloudClient.new(self.user)
      user_client.delete_method(self.namespace, self.name, self.snapshot)
      Rails.logger.info "#{self.full_name} successfully redacted from methods repo"
    rescue => e
      Rails.logger.error "Unable to add #{self.full_name} to methods repo: #{e.message}"
    end
  end
end
