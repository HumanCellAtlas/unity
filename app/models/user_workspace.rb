class UserWorkspace < ApplicationRecord
  belongs_to :user
  belongs_to :project

  attribute :name, :string

  validates_format_of :name, with: ALPHANUMERIC_EXTENDED, message: ALPHANUMERIC_EXTENDED_MESSAGE
  validates_presence_of :name
  validates_uniqueness_of :name, scope: :project_id

  def namespace
    self.project.namespace
  end
end
