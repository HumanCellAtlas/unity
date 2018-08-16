class RenameReferenceAnalysisDataGsUrl < ActiveRecord::Migration[5.2]
  def change
    rename_column :reference_analysis_data, :gs_url, :parameter_value
  end
end
