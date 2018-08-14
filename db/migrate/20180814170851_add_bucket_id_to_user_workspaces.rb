class AddBucketIdToUserWorkspaces < ActiveRecord::Migration[5.2]
  def change
    add_column :user_workspaces, :bucket_id, :string
  end
end
