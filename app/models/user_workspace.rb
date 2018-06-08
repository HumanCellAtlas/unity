class UserWorkspace < ApplicationRecord
  belongs_to :user
  belongs_to :project

  attribute :name, :string

  validates :name, format: ValidationTools::ALPHANUMERIC_AND_DASH,
                   presence: true,
                   uniqueness: true, scope: :project_id

  def namespace
    self.project.namespace
  end
end
