class AddStimsetIdToImageChoices < ActiveRecord::Migration
  def change
    add_column :image_choices, :stimset_id, :string
  end
end
