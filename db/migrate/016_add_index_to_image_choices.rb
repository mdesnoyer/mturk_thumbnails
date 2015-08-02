class AddIndexToImageChoices < ActiveRecord::Migration
  def change
    add_index :image_choices, :stimset_id
  end
end
