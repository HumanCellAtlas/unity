class BenchmarkAnalysis < ApplicationRecord
  belongs_to :user_analysis
  belongs_to :user

  attribute :name, :string
  attribute :namespace, :string
  attribute :snapshot, :integer
  attribute :configuration_name, :string
  attribute :configuration_namespace, :string
  attribute :configuration_snapshot, :integer
  attribute :submission_id, :string
  attribute :submission_status, :string
  attribute :benchmark_results, :string

  validates_presence_of :name, :namespace, :snapshot, :configuration_name, :configuration_namespace, :configuration_snapshot
  validates_format_of :name, :namespace, :configuration_name, :configuration_namespace,
                      with: ALPHANUMERIC_EXTENDED, message: ALPHANUMERIC_EXTENDED_MESSAGE

  before_destroy :remove_method_from_repository

  private

  # redact all versions of this analysis from the methods repo
  def remove_method_from_repository
    begin
      user_client = FireCloudClient.new(self.user)
      max_snapshot = self.snapshot
      max_snapshot.downto(1) do |version|
        Rails.logger.info "Redacting #{self.full_name}/#{version} from methods repo"
        user_client.delete_method(self.namespace, self.name, version)
        Rails.logger.info "#{self.full_name}/#{version} successfully redacted from methods repo"
      end
    rescue => e
      Rails.logger.error "Unable to redact #{self.full_name} to methods repo: #{e.message}"
    end
  end
end
