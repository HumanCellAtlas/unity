class UserWorkspace < ApplicationRecord
  belongs_to :user
  belongs_to :project

  attribute :name, :string

  validates :name, format: ValidationTools::ALPHANUMERIC_AND_DASH,
                   presence: true
  validates_uniqueness_of :name, scope: :project_id

  def namespace
    self.project.namespace
  end
end
