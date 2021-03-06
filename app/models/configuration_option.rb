class ConfigurationOption < ApplicationRecord

  belongs_to :admin_configuration

  attribute :name, :string
  attribute :value, :string

  validates_presence_of :name, :value
  validates_uniqueness_of :value, scope: [:admin_configuration_id, :name]
  validates_format_of :value, with: OBJECT_LABELS, message: OBJECT_LABELS_MESSAGE
end
