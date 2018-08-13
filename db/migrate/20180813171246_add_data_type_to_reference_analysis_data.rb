class AddDataTypeToReferenceAnalysisData < ActiveRecord::Migration[5.2]
  def change
    add_column :reference_analysis_data, :data_type, :string
    add_column :reference_analysis_data, :call_name, :string
  end
end
