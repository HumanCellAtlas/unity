class AddUsersToReferenceAnalysis < ActiveRecord::Migration[5.2]
  def change
    add_column :reference_analyses, :user_id, :bigserial
  end
end
