class AddReactionTimeToImageChoices < ActiveRecord::Migration
  def change
    add_column :image_choices, :reaction_time, :integer
  end
end
