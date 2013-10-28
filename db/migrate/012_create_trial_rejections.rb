class CreateTrialRejections < ActiveRecord::Migration
  def change
    create_table :trial_rejections do |t|
      t.string :worker_id
      t.string :stimset
      t.string :reason
      t.integer :count
    end
  end
end
