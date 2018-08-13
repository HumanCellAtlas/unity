class CreateReferenceAnalysisOptions < ActiveRecord::Migration[5.2]
  def change
    create_table :reference_analysis_options do |t|
      t.bigserial :reference_analysis_id
      t.string :name
      t.string :value

      t.timestamps
    end
  end
end
