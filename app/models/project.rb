class Project < ApplicationRecord
  belongs_to :user

  attribute :namespace, :string
  attribute :user_role, :string

  validates_uniqueness_of :namespace, scope: [:user_id]
  validates_presence_of :namespace, :user_role
  validates_format_of :namespace, with: ALPHANUMERIC_EXTENDED, message: ALPHANUMERIC_EXTENDED_MESSAGE
  validate :verify_project_membership
  validates :user_role, inclusion: {in: %w(Member Owner)}

  def self.owned_by(user)
    Project.where(user_id: user.id)
  end

  def user_is_owner?
    self.user_role == 'Owner'
  end

  private

  # validate that the user is a member of the registered project
  def verify_project_membership
    if self.namespace.blank?
      false # just return false as the namespace validation will catch this and set the proper error
    else
      client = FireCloudClient.new(self.user, self.namespace)
      begin
        projects = client.get_billing_projects
        fc_project = projects.detect {|acl| acl['projectName'] == self.namespace}
        if fc_project.present?
          # set the project user role
          self.user_role = fc_project['role']
          true
        else
          errors.add(:namespace, " - You must be a member of '#{self.namespace}' to use it with Unity.  Please select another project.")
        end
      rescue => e
        Rails.logger.error "#{Time.now} - unable to verify project membership of #{self.namespace} for #{self.user.email}: #{e.message}"
        errors.add(:namespace, " - We are unable to verify project permissions for #{self.namespace} due to an error.  Please select another project.")
      end
    end
  end
end
