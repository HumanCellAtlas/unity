class AddOptionalToReferenceAnalysisDatum < ActiveRecord::Migration[5.2]
  def change
    add_column :reference_analysis_data, :optional, :boolean, default: false
  end
end
