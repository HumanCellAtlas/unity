class ReferenceAnalysisDatum < ApplicationRecord
  belongs_to :reference_analysis

  attribute :data_type, :string # input, output
  attribute :call_name, :string # name of WDL task this input
  attribute :parameter_name, :string # name of the parameter from the WDL
  attribute :gs_url, :string # gs:// style URL to file

  DATA_TYPES = %w(input output)

  validates_presence_of :parameter_name, :gs_url, :call_name, :data_type
  validates_format_of :parameter_name, with: ALPHANUMERIC_ONLY, message: ALPHANUMERIC_ONLY_MESSAGE
  validates_format_of :call_name, with: FILENAME_CHARS, message: FILENAME_CHARS_MESSAGE
  validates_format_of :gs_url, with: OBJECT_LABELS, message: OBJECT_LABELS_MESSAGE
  validates_uniqueness_of :parameter_name, :gs_url, scope: [:data_type, :call_name, :reference_analysis_id]
  validates_inclusion_of :data_type, in: DATA_TYPES

end
