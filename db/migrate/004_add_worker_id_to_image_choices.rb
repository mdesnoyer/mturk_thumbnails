class AddWorkerIdToImageChoices < ActiveRecord::Migration
  def change
    add_column :image_choices, :worker_id, :string
  end
end
