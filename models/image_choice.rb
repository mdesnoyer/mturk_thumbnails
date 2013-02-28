class ImageChoice < ActiveRecord::Base
  def self.worker_choices
    worker_ids = ImageChoice.select(:worker_id).uniq.pluck(:worker_id)
    results = {}

    worker_ids.each do |wid|
      worker_result = results[wid] = Hash.new { |hash, image| hash[image] = 0 }

      ImageChoice.where(worker_id: wid).all.each do |image_choice|
        if image_choice.condition == 'KEEP'
          worker_result[image_choice.chosen_image] += 1
        else
          worker_result[image_choice.chosen_image] -= 1
        end
      end
    end

    results
  end
end
