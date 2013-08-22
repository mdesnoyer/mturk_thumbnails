require 'csv'

task calculate_scores: :environment do
  stimsets = ImageChoice.select('distinct stimset_id').map(&:stimset_id)
  results = {}

  stimsets.each do |stimset|
    stimset_results = results[stimset] = {}
    worker_ids = ImageChoice.where(trial: 288, stimset_id: stimset).select(:worker_id).map(&:worker_id)
    worker_count = worker_ids.size
    scores = Hash.new { |h, k| h[k] = 0 }
  
    worker_ids.each do |worker_id|
      trials = ImageChoice.where(worker_id: worker_id, stimset_id: stimset).all
      unique_trials = trials.uniq_by(&:trial)

      unique_trials.each do |trial|
        if trial.chosen_image != 'NONE'
          if trial.condition == 'KEEP'
            scores[trial.chosen_image] += 1
          else
            scores[trial.chosen_image] -= 1
          end
        end
      end
    end
  
    scores.each do |img, score|
      stimset_results[img] = (score/worker_count.to_f).round(3)
    end
  end

  filename = "#{Date.today.strftime('%Y-%m-%d')}-scores.csv"
  path = "#{PADRINO_ROOT}/tmp/#{filename}"

  CSV.open(path, 'w') do |csv|
    results.each do |stimset, scores|
      scores.each do |img, score|
        csv << [img, score, stimset]
      end
    end
  end

  s3 = AWS::S3.new(access_key_id: ENV['S3_KEY'], secret_access_key: ENV['S3_SECRET'])
  bucket = s3.buckets['mturk-results']
  bucket.objects[filename].write(Pathname.new(path))
end