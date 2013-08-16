class CreateWorkerInfo < ActiveRecord::Migration
  def change
    create_table :worker_info do |t|
      t.string :worker_id
      t.string :remote_ip
      t.string :x_forwarded_for
      t.timestamps
    end
  end
end
