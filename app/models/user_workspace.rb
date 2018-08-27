class UserWorkspace < ApplicationRecord
  belongs_to :user
  belongs_to :project
  belongs_to :reference_analysis

  has_one :user_analysis, dependent: :destroy # call destroy to have callbacks fire

  attribute :name, :string
  attribute :bucket_id, :string

  validates_format_of :name, with: ALPHANUMERIC_EXTENDED, message: ALPHANUMERIC_EXTENDED_MESSAGE
  validates_uniqueness_of :name, scope: :project
  validates_presence_of :name, :user, :project, :reference_analysis
  validate :create_benchmark_workspace

  def full_name
    [self.namespace, self.name].join('/')
  end

  # name as DOM element ID
  def name_as_id
    self.name.gsub(/\//, '-')
  end

  # full name as DOM element ID
  def full_name_as_id
    self.full_name.gsub(/\//, '-')
  end

  def namespace
    self.project.namespace
  end

  def self.owned_by(user)
    if user.present?
      self.where(user_id: user.id)
    else
      []
    end
  end

  # generate a default name based off of reference analysis name on initialization
  def default_name
    self.reference_analysis.extract_wdl_keys(:analysis_wdl).join('-')
  end

  # helper to generate a URL to a workspace's GCP bucket
  def google_bucket_url
    "https://accounts.google.com/AccountChooser?continue=https://console.cloud.google.com/storage/browser/#{self.bucket_id}"
  end

  # helper to generate a URL to a specific FireCloud submission inside a workspace's GCP bucket
  def submission_url(submission_id)
    self.google_bucket_url + "/#{submission_id}"
  end

  private

  # create a new benchmark workspace by cloning the reference workspace
  def create_benchmark_workspace
    begin
      user_client = FireCloudClient.new(self.user)
      Rails.logger.info "Creating user_workspace: #{self.full_name} from #{self.reference_analysis.display_name}"
      # clone reference space into new workspace
      workspace = user_client.clone_workspace(self.reference_analysis.firecloud_project, self.reference_analysis.firecloud_workspace,
                                              self.namespace, self.name)
      ws_name = workspace['name']
      # validate creation
      unless ws_name == self.name
        # delete workspace on validation fail
        user_client.delete_workspace(self.namespace, self.name)
        errors.add(:name, ' was not created properly (workspace name did not match or was not created).  Please try again later.')
        return false
      end
      Rails.logger.info "Setting bucket ID for #{self.full_name}"
      bucket = workspace['bucketName']
      self.bucket_id = bucket
      if self.bucket_id.nil?
        user_client.delete_workspace(self.namespace, self.name)
        errors.add(:name, ' was not created properly (storage bucket was not set).  Please try again later.')
        return false
      end
      Rails.logger.info "Adding GCS Admin ACL to #{self.full_name}"
      gcs_admin_acl = user_client.create_workspace_acl(ApplicationController.gcs_client.issuer, 'WRITER', true, false)
      user_client.update_workspace_acl(self.namespace, self.name, gcs_admin_acl)
    rescue => e
      Rails.logger.error "Error creating user workspace #{self.full_name}: #{e.message}"
      if e.message.include?("Workspace #{self.full_name} already exists")
        errors.add(:name, ' - there is already an existing benchmarking workspace using this name.  Please choose another name.')
      else
        begin
          FireCloudClient.new(self.user).delete_workspace(self.namespace, self.name)
        rescue => e
          Rails.logger.error "Cannot remove workspace #{self.full_name} due to error: #{e.message}"
        end
          errors.add(:name, " creation failed: #{e.message}; Please try again.")
      end
    end
  end
end
