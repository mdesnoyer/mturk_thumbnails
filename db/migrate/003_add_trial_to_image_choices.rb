class AddTrialToImageChoices < ActiveRecord::Migration
  def change
    add_column :image_choices, :trial, :integer
  end
end
