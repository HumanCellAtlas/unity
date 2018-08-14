class FireCloudProfile
  include ActiveModel::Model
  include ValidationTools

  attr_accessor :contactEmail, :email, :firstName, :lastName, :institute, :institutionalProgram,
                :nonProfitStatus, :pi, :programLocationCity, :programLocationState,
                :programLocationCountry, :title

  validates_presence_of :contactEmail, :email, :firstName, :lastName, :institute, :institutionalProgram,
                        :nonProfitStatus, :pi, :programLocationCity, :programLocationState,
                        :programLocationCountry, :title

  validates_format_of :firstName, :lastName, :pi, :programLocationCity,
                      :programLocationState, :programLocationCountry, with: ALPHANUMERIC_SPACE,
                      message: ALPHANUMERIC_SPACE_MESSAGE

  validates_format_of :institute, :institutionalProgram, :title, with: OBJECT_LABELS,
                      message: OBJECT_LABELS_MESSAGE

  validates_format_of :email, :contactEmail, with: Devise.email_regexp, message: 'is not a valid email address.'

  validates_inclusion_of :nonProfitStatus, in: ['true', 'false']
end