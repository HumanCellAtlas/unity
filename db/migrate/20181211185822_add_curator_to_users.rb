class AddCuratorToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :curator, :boolean, default: false
  end
end
