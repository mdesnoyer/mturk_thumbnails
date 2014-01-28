class CreateRejectionWarnings < ActiveRecord::Migration
  def change
    create_table :rejection_warnings do |t|
      t.string :worker_id
      t.datetime :last_warning_time
      t.integer :last_warning_level
    end
  end
end
