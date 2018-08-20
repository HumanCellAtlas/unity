class CreateBenchmarkAnalyses < ActiveRecord::Migration[5.2]
  def change
    create_table :benchmark_analyses do |t|
      t.bigserial :user_analysis_id
      t.bigserial :user_id
      t.string :name
      t.string :namespace
      t.integer :snapshot
      t.string :configuration_name
      t.string :configuration_namespace
      t.integer :configuration_snapshot
      t.string :submission_id
      t.string :submission_status
      t.string :benchmark_results

      t.timestamps
    end
  end
end
