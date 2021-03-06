ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :admin_configurations

  # Add more helper methods to be used by all tests here...
  def compare_hashes(reference, compare)
    ref = reference.to_a.flatten
    comp = compare.to_a.flatten
    if (ref.size > comp.size)
      difference = ref - comp
    else
      difference = comp - ref
    end
    Hash[*difference.flatten]
  end
end
