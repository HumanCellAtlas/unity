class CreateUserAnalyses < ActiveRecord::Migration[5.2]
  def change
    create_table :user_analyses do |t|
      t.bigserial :user_workspace_id
      t.bigserial :user_id
      t.string :namespace
      t.string :name
      t.integer :snapshot
      t.text :wdl_contents

      t.timestamps
    end
  end
end
