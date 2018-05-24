class CreateConfigurationOptions < ActiveRecord::Migration[5.2]
  def change
    create_table :configuration_options do |t|
      t.bigserial :admin_configuration_id
      t.string :name
      t.string :value

      t.timestamps
    end
  end
end
