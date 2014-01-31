class CreateFilterStats < ActiveRecord::Migration
  def change
    create_table :filter_stats do |t|
      t.string :worker_id
      t.string :stimset
      t.float :p_rand
      t.int :max_same_slot
    end
  end
end
