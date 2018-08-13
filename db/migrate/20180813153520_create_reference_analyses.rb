class CreateReferenceAnalyses < ActiveRecord::Migration[5.2]
  def change
    create_table :reference_analyses do |t|
      t.string :firecloud_project
      t.string :firecloud_workspace
      t.string :analysis_wdl
      t.string :benchmark_wdl
      t.string :orchestration_wdl

      t.timestamps
    end
  end
end
