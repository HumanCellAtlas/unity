class AddUserRoleToProjects < ActiveRecord::Migration[5.2]
  def change
    add_column :projects, :user_role, :string
  end
end
