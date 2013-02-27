class AddConditionToImageChoices < ActiveRecord::Migration
  def change
    add_column :image_choices, :condition, :string
  end
end
