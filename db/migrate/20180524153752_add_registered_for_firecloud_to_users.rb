class AddRegisteredForFirecloudToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :registered_for_firecloud, :boolean, default: false
  end
end
