require 'test_helper'

class ReferenceAnalysisTest < ActiveSupport::TestCase

  def setup
    @reference_analysis = ReferenceAnalysis.first
  end

  test 'load required parameters from methods repo' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    namespace, name, snapshot = @reference_analysis.extract_wdl_keys(:analysis_wdl)
    remote_config = ApplicationController.fire_cloud_client.get_method_parameters(namespace, name, snapshot.to_i)
    local_config = @reference_analysis.configuration_settings
    assert local_config === remote_config, "local config does not match remote config; diff: #{compare_hashes(remote_config, local_config)}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'can extract wdl keys' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    [:analysis_wdl, :benchmark_wdl, :orchestration_wdl].each do |wdl_key|
      raw_keys = @reference_analysis.send(wdl_key).split('/')
      extracted_keys = @reference_analysis.extract_wdl_keys(wdl_key)
      assert extracted_keys == raw_keys, "did not extract wdl keys for #{wdl_key} correctly, expected #{raw_keys} but found #{extracted_keys}"
    end

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'can extract required inputs from configuration' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    namespace, name, snapshot = @reference_analysis.extract_wdl_keys(:analysis_wdl)
    remote_config = ApplicationController.fire_cloud_client.get_method_parameters(namespace, name, snapshot.to_i)
    inputs = @reference_analysis.required_inputs
    assert remote_config['inputs'] == inputs, "required inputs do not match; diff: #{compare_hashes(remote_config['inputs'], inputs)}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'can extract required outputs from configuration' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    namespace, name, snapshot = @reference_analysis.extract_wdl_keys(:analysis_wdl)
    remote_config = ApplicationController.fire_cloud_client.get_method_parameters(namespace, name, snapshot.to_i)
    outputs = @reference_analysis.required_outputs
    assert remote_config['outputs'] == outputs, "required inputs do not match; diff: #{compare_hashes(remote_config['outputs'], outputs)}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end
