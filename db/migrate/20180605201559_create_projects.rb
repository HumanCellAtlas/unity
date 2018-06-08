class CreateProjects < ActiveRecord::Migration[5.2]
  def change
    create_table :projects do |t|
      t.bigserial :user_id
      t.string :namespace, null: :false

      t.timestamps
    end
  end
end
