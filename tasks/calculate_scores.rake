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

    stimset_ids = ImageChoice.where('stimset_id IS NOT NULL').select(:stimset_id).uniq.pluck(:stimset_id)
    stimsets = stimset_ids.uniq_by do |id|
      match = id.match(/([0-9a-zA-Z_]+)_[0-9a-f]+/)
      match && match[1]
    end
    for stimset in stimsets
      if stimset.nil? or stimset.empty?
        next
      end

      # for each image, to counts of [<keep_view>, <return_view>,
      # <keep_clicks>, <return_clicks]
      counts = Hash.new { |h, k| h[k] = [0, 0, 0, 0] }

      workers = ImageChoice.select('distinct worker_id').where(
        'stimset_id like ?', "#{stimset}\\_%").map(&:worker_id)
      for worker_id in workers
        filtered_result = TurkFilter.get_filtered_trials(worker_id, stimset)

        # Record the scores on the filter
        FilterStat.where(:worker_id => worker_id,
                         :stimset => stimset).first_or_create do |filter_stats|
          filter_stats.p_rand = filtered_result['worker_scores']['TooRandom']
          filter_stats.max_same_slot = 
            filtered_result['worker_scores']['TooManyClicksInSameSlot']
        end

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
        end
      end
    end
  end
end
