class CreateReferenceAnalysisData < ActiveRecord::Migration[5.2]
  def change
    create_table :reference_analysis_data do |t|
      t.bigserial :reference_analysis_id
      t.string :parameter_name
      t.string :gs_url

      t.timestamps
    end
  end
end
