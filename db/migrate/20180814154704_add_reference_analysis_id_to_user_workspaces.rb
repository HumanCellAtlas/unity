class AddReferenceAnalysisIdToUserWorkspaces < ActiveRecord::Migration[5.2]
  def change
    add_column :user_workspaces, :reference_analysis_id, :bigserial
  end
end
