module ValidationTools
  # validators
  ALPHANUMERIC_ONLY = /\A\w*\z/ # alphanumeric characters only
  ALPHANUMERIC_EXTENDED = /\A[\w+\-\/]+\z/ # alphanumeric plus - /
  ALPHANUMERIC_PERIOD = /\A[\w+\.]+\z/ # alphanumeric plus .
  ALPHANUMERIC_SPACE = /\A[\w+\s]*\z/ # alphanumeric and whitespace
  FILENAME_CHARS = /\A[\w+[\s\-\.\/\(\)]?]+\z/ # alphanumeric and whitespace plus - . / ( )
  OBJECT_LABELS = /\A[\w+\s*[\-\.\/\(\)\+\,\:]?]+\z/ # alphanumeric and whitespace plus - . / ( ) + , :

  # error messages
  ALPHANUMERIC_ONLY_MESSAGE = 'contains invalid characters. Please use only alphanumeric characters.'
  ALPHANUMERIC_EXTENDED_MESSAGE = 'contains invalid characters. Please use only alphanumeric or the following: - _ /'
  ALPHANUMERIC_PERIOD_MESSAGE = 'contains invalid characters. Please use only alphanumeric or .'
  ALPHANUMERIC_SPACE_MESSAGE = 'contains invalid characters. Please use only alphanumeric or whitespace'
  FILENAME_CHARS_MESSAGE = 'contains invalid characters. Please use only alphanumeric, spaces, or the following: - _ . / ( )'
  OBJECT_LABELS_MESSAGE = 'contains invalid characters. Please use only alphanumeric, spaces, or the following: - _ . / ( ) + , :'

  # generate a random n-character alphanumeric string
  def self.random_alphanumeric(length=8)
    [*('a'..'z'),*('0'..'9')].shuffle[0,length].join
  end
end