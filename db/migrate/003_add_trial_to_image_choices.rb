class AddTrialToImageChoices < ActiveRecord::Migration
  def change
    add_column :image_choices, :trial, :string
  end
end
