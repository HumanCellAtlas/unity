class AddAddedToUnityGroupToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :added_to_unity_group, :boolean, default: false
  end
end
