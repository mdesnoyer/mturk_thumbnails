class AddDemographicsToWorkerInfo < ActiveRecord::Migration
  def change
    add_column :worker_info, :gender, :string, :limit => 1
    add_column :worker_info, :age_group, :string
  end
end
