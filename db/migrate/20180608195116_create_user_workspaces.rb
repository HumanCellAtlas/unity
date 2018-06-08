class CreateUserWorkspaces < ActiveRecord::Migration[5.2]
  def change
    create_table :user_workspaces do |t|
      t.string :name
      t.bigserial :project_id
      t.bigserial :user_id

      t.timestamps
    end
  end
end
