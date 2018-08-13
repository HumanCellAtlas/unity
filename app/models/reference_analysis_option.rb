class ReferenceAnalysisOption < ApplicationRecord

  belongs_to :reference_analysis

  attribute :name, :string
  attribute :value, :string

  validates_presence_of :name, :value
  validates_uniqueness_of :value, scope: [:reference_analysis_id, :name]
  validates_format_of :value, with: OBJECT_LABELS, message: OBJECT_LABELS_MESSAGE
end
