require 'csv'
require 'turk_filter'

begin
  require 'debugger'
rescue LoadError
end

namespace :calculate_scores do
  
  task :prod => :environment do
    # Connect to the production database instead of the local one
    ActiveRecord::Base.establish_connection(
      ActiveRecord::Base.configurations[:remote_production])

    Rake::Task['calculate_scores:default'].invoke

    # Close connection to the production database
    ActiveRecord::Base.establish_connection(ENV['RAILS_ENV'])
  end

  task :staging => :environment do
    # Connect to the production database instead of the local one
    ActiveRecord::Base.establish_connection(
      ActiveRecord::Base.configurations[:remote_staging])

    Rake::Task['calculate_scores:default'].invoke

    # Close connection to the production database
    ActiveRecord::Base.establish_connection(ENV['RAILS_ENV'])
  end

  task :default => :environment do
    results = {}

    # First delete the entries in the rejection database
    UserRejection.delete_all()
    TrialRejection.delete_all()
    ImageScore.delete_all()

    stimsets = ImageChoice.select('distinct substring(stimset_id from E\'(stimuli_[0-9]+)\\_[0-9a-f]+\') as stim').map(&:stim)
    for stimset in stimsets
      if stimset.nil? or stimset.empty?
        next
      end
      stimset_results = results[stimset] = {}


      # for each image, to counts of [<keep_view>, <return_view>,
      # <keep_clicks>, <return_clicks]
      counts = Hash.new { |h, k| h[k] = [0, 0, 0, 0] }

      workers = ImageChoice.select('distinct worker_id').where(
        'stimset_id like ?', "#{stimset}\\_%").map(&:worker_id)
      for worker_id in workers
        filtered_result = TurkFilter.get_filtered_trials(worker_id, stimset)
        if not filtered_result['worker_rejection'].nil?
          # This user was filtered, so record it
          UserRejection.create(worker_id: worker_id, stimset: stimset,
                               reason: filtered_result['worker_rejection'])
          next
        end

        # Record the number of trials rejected and for what reason
        filtered_result['trial_rejections'].each do |reason, count|
          TrialRejection.create(worker_id: worker_id, stimset: stimset,
                                reason: reason, count: count)
        end
        
        trials = filtered_result['trials']
        for trial in trials
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
      
      ImageScore.transaction do
        counts.each do |img, count|
          if count[0] == 0 or count[1] == 0
            next
          end
          score = count[2].to_f / count[0] - count[3].to_f / count[1]
          score = score.round(3)

          # Record the image score in the database
          ImageScore.create(image: img, valence: score, stimset: stimset,
                            valid_keeps: count[0], valid_returns: count[1])

          # Make sure that there is enough data for this image
          if (count[0] + count[1]) / 2 < 100
            next
          end

          stimset_results[img] = score
        end
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
