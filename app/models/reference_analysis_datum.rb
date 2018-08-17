class ReferenceAnalysisDatum < ApplicationRecord
  belongs_to :reference_analysis

  attribute :data_type, :string # input, output
  attribute :call_name, :string # name of WDL task this input
  attribute :parameter_type, :string # type of the parameter (from primitive/compound types)
  attribute :parameter_name, :string # name of the parameter from the WDL
  attribute :parameter_value, :string # value of the parameter (optional)
  attribute :optional, :boolean, default: false # parameter optional?

  DATA_TYPES = %w(inputs outputs)
  PRIMITIVE_PARAMETER_TYPES = %w(String Int Float File Boolean String? Int? Float? File? Boolean?)
  COMPOUND_PARAMETER_TYPES = %w(Array Map Object)

  validates_presence_of :data_type, :call_name, :parameter_type, :parameter_name
  validates_format_of :parameter_name, with: ALPHANUMERIC_PERIOD, message: ALPHANUMERIC_PERIOD_MESSAGE
  validates_format_of :call_name, with: FILENAME_CHARS, message: FILENAME_CHARS_MESSAGE
  validates_format_of :parameter_value, with: OBJECT_LABELS, message: OBJECT_LABELS_MESSAGE, allow_blank: true
  validates_uniqueness_of :parameter_name, scope: [:data_type, :call_name, :reference_analysis_id]
  validates_inclusion_of :data_type, in: DATA_TYPES
  validate :validate_parameter_type

  private

  # ensure parameter type conforms to WDL input types
  def validate_parameter_type
    if PRIMITIVE_PARAMETER_TYPES.include? self.parameter_type || self.parameter_type === 'Object'
      true
    elsif self.parameter_type.include?('[') # compound types have brackets []
      # extract primitives from complex type
      raw_primitives = self.parameter_type.split('[').last
      raw_primitives.gsub!(/]\??/, '')
      primitives = raw_primitives.split(',').map(&:strip)
      if self.parameter_type.start_with?('Array')
        # there is only one primitive type from the control list
        unless primitives.size === 1 && PRIMITIVE_PARAMETER_TYPES.include?(primitives.first)
          errors.add(:parameter_type, "has an invalid primitive type: #{(primitives - PRIMITIVE_PARAMETER_TYPES).join(', ')}")
        end
      elsif self.parameter_type.start_with?('Map')
        # there are two primitive types, and the intersection is the same as the unique list of primitives
        unless primitives.size === 2 && (primitives & PRIMITIVE_PARAMETER_TYPES === primitives.uniq)
          errors.add(:parameter_type, "has an invalid primitive type: #{(primitives - PRIMITIVE_PARAMETER_TYPES).join(', ')}")
        end
      else
        errors.add(:parameter_type, "has an invalid complex type: #{self.parameter_type.split('[').first}")
      end
    else
      errors.add(:parameter_type, "has an invalid value: #{self.parameter_type}")
    end
  end
end
