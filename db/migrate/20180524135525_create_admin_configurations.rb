class CreateAdminConfigurations < ActiveRecord::Migration[5.2]
  def change
    create_table :admin_configurations do |t|
      t.string :config_type
      t.string :value_type
      t.string :value

      t.timestamps
    end
  end
end
