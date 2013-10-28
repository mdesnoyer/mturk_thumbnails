class CreateUserRejections < ActiveRecord::Migration
  def change
    create_table :user_rejections do |t|
      t.string :worker_id
      t.string :stimset
      t.string :reason
    end
  end
end
