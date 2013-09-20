class CreateJobsCompleted < ActiveRecord::Migration
  def change
    create_table :jobs_completed do |t|
      t.string :worker_id
      t.string :stimset
    end
  end
end
