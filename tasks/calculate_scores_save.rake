# I'm modifying calculate_Scores to output all the filtered trials to
# a .csv file; hopefully this will work.
require 'turk_filter'
require 'csv'

begin
  require 'debugger'
rescue LoadError
end

namespace :calculate_scores_save do

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
    puts 'Beginning'
    stimsets = ImageChoice.select('distinct substring(stimset_id from E\'([0-9a-zA-Z_]+)\\_[0-9a-f]+\') as stim').map(&:stim)
    puts 'opening csv'
    CSV.open("/home/nick/filtered_trials.csv","wb") do |csv|
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
          csv << ['id','assignment_id','image_one','image_two','image_three''chosen_image','created_at','updated_at','condition','trial','worker_id','stimset_id','reaction_time']
          trials.each do |trial|
            csv << [trial.id, trial.assignment_id, trial.image_one, trial.image_two, trial.image_three, trial.chosen_image, trial.created_at, trial.updated_at, trial.condition, trial.trial, trial.worker_id, trial.stimset_id, trial.reaction_time]
          end
        end
      end
    end
  end
end
