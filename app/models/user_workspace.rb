class UserWorkspace < ApplicationRecord
  belongs_to :user
  belongs_to :project
  belongs_to :reference_analysis

  attribute :name, :string
  attribute :bucket_id, :string

  validates_format_of :name, with: ALPHANUMERIC_EXTENDED, message: ALPHANUMERIC_EXTENDED_MESSAGE
  validates_uniqueness_of :name, scope: :project
  validates_presence_of :name, :user, :project, :reference_analysis
  validate :create_benchmark_workspace

  def full_name
    [self.namespace, self.name].join('/')
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

  # set a default name based off of reference analysis name on initialization
  after_initialize do |user_workspace|
    if self.reference_analysis.present?
      user_workspace.name = reference_analysis.extract_wdl_keys(:analysis_wdl).join('-')
    end
  end

  private

  # create a new benchmark workspace by cloning the reference workspace
  def create_benchmark_workspace
    begin
      user_client = FireCloudClient.new(self.user, self.namespace)
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
    rescue => e
      Rails.logger.info "Error creating user workspace #{self.full_name}: #{e.message}"
      if e.message.include?("Workspace #{self.full_name} already exists")
        errors.add(:name, ' - there is already an existing benchmarking workspace using this name.  Please choose another name.')
      else
        user_client.delete_workspace(self.namespace, self.name)
        errors.add(:name, " creation failed: #{e.message}; Please try again.")
      end
    end
  end
end
