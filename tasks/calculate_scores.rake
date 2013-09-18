require 'csv'
require 'turk_filter'

namespace :calculate_scores do
  
  task :prod => :environment do
    # Connect to the production database instead of the local one
    ActiveRecord::Base.establish_connection(
      ActiveRecord::Base.configurations[:remote_production])

    Rake::Task['calculate_scores:default'].invoke

    # Close connection to the production database
    ActiveRecord::Base.establish_connection(ENV['RAILS_ENV'])
  end

  task :default => :environment do
    results = {}

    stimsets = ImageChoice.select('distinct substring(stimset_id from \'stimuli_[0-9]+\') as stim').map(&:stim)
    for stimset in stimsets
      if stimset.nil? or stimset.empty?
        next
      end
      stimset_results = results[stimset] = {}

      # for each image, to counts of [<keep_view>, <return_view>,
      # <keep_clicks>, <return_clicks]
      counts = Hash.new { |h, k| h[k] = [0, 0, 0, 0] }

      workers = ImageChoice.select('distinct worker_id').where(
        'stimset_id like ?', "#{stimset}%").map(&:worker_id)
      for worker_id in workers
        for trial in TurkFilter.get_filtered_trials(worker_id, stimset)['trials']
          if trial.chosen_image != 'NONE' and trial.chosen_image != ''
            if trial.condition == 'KEEP'
              counts[trial.chosen_image][2] += 1
              counts[trial.image_one][0] += 1
              counts[trial.image_two][0] += 1
              counts[trial.image_three][0] += 1
            else
              counts[trial.chosen_image][3] += 1
              counts[trial.image_one][1] += 1
              counts[trial.image_two][1] += 1
              counts[trial.image_three][1] += 1
            end
          end
        end
      end
      
      counts.each do |img, count|
        # Make sure that there is enough data for this image
        # TODO(deb): Figure out what this number should be
        if count[0] < 50 or count[1] < 50
          next
        end
        score = count[2].to_f / count[0] - count[3].to_f / count[1]
        stimset_results[img] = score.round(3)
      end
    end

    filename = "#{Date.today.strftime('%Y-%m-%d')}-scores.csv"

    score_string = CSV.generate do |csv|
      results.each do |stimset, scores|
        scores.each do |img, score|
          csv << [img, score, stimset]
        end
      end
    end

    if ENV['S3_KEY'].nil? or ENV['S3_KEY'].empty? then
      File.open(filename, 'w') { |f| f.write(score_string) }
      puts("Wrote results to #{filename}")
    else
      s3 = AWS::S3.new(access_key_id: ENV['S3_KEY'],
                       secret_access_key: ENV['S3_SECRET'])
      bucket = s3.buckets['mturk-results']
      bucket.objects[filename].write(score_string)

      puts("Wrote #{filename} to S3")
    end
  end
end
