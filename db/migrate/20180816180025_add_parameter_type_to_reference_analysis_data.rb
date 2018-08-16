class AddParameterTypeToReferenceAnalysisData < ActiveRecord::Migration[5.2]
  def change
    add_column :reference_analysis_data, :parameter_type, :string
  end
end
