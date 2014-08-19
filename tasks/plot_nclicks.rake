# Script to help find out how many valid image clicks are needed
# in order to reduce the error to a reasonable level.
#
# Copyright 2013 Neon Labs

require 'turk_filter'

begin
  require 'rsruby'
  require 'debugger'
rescue LoadError
end

namespace :plot_nclicks do 

  task :prod => :environment do
    # Connect to the production database instead of the local one
    ActiveRecord::Base.establish_connection(
      ActiveRecord::Base.configurations[:remote_production])

    Rake::Task['plot_nclicks:default'].invoke

    # Close connection to the production database
    ActiveRecord::Base.establish_connection(ENV['RAILS_ENV'])
  end

  task :default => :environment do
    worker_counts = []
    
    # First collect all the counts from the database for every worker
    workers = ImageChoice.select('distinct worker_id').where(
        'stimset_id like ?', "sophie_greece%").map(&:worker_id)
    for worker_id in workers
      filtered_result = TurkFilter.get_filtered_trials(worker_id, 'sophie_greece')

      counts = Hash.new { |h, k| h[k]=[0, 0, 0, 0] }

      for trial in filtered_result['trials']
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

      worker_counts << counts
    end
    
    # Calculate the true scores
    tru_scores, garb = get_image_scores(worker_counts)

    # Sample the scores
    N_SAMPLES=5
    WORKER_STEP=2
    workers = []
    mean_errors = []
    rng = Random.new(49816549)
    for n_workers in (20..60).step(WORKER_STEP) do
      workers << n_workers
      mean_errors << get_mean_error(tru_scores, worker_counts, n_workers,
                                    N_SAMPLES, rng)
    end

    # Do the plotting
    r = RSRuby.instance
    r.plot(:x => workers,
           :y => mean_errors,
           :xlab => '# of workers',
           :ylab => 'Sum Squared Error')
    $stdin.gets.chomp
    
  end

end
