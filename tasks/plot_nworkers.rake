# Script to help find out how many workers need to be in the experiment
# in order to reduce the error to a reasonable level.
#
# Author: Mark Desnoyer (desnoyer@neon-lab.com)
# Copyright 2013 Neon Labs

require 'turk_filter'
require 'debugger'

begin
  require 'rsruby'
rescue LoadError
end

namespace :plot_nworkers do    

  task :prod => :environment do
    # Connect to the production database instead of the local one
    ActiveRecord::Base.establish_connection(
      ActiveRecord::Base.configurations[:remote_production])

    Rake::Task['plot_nworkers:default'].invoke

    # Close connection to the production database
    ActiveRecord::Base.establish_connection(ENV['RAILS_ENV'])
  end

  task :default => :environment do
    worker_counts = []
    
    # First collect all the counts from the database for every worker
    workers = ImageChoice.select('distinct worker_id').where(
        'stimset_id like ?', "faces1%").map(&:worker_id)
    for worker_id in workers
      filtered_result = TurkFilter.get_filtered_trials(worker_id, 'faces1')

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

      puts "rejection: #{filtered_result['worker_rejection']}"

      worker_counts << counts
    end
    
    # Calculate the true scores
    tru_scores, garb = get_image_scores(worker_counts)

    # Sample the scores
    N_SAMPLES=5
    WORKER_STEP=4
    workers = []
    mean_errors = []
    mean_views = []
    rng = Random.new(49816549)
    for n_workers in (20..100).step(WORKER_STEP) do
      workers << n_workers
      mean_error, mean_view = get_mean_error(tru_scores, worker_counts,
                                             n_workers, N_SAMPLES, rng)
      mean_errors << mean_error
      mean_views << mean_view
    end

    # Do the plotting
    r = RSRuby.instance
    r.plot(:x => workers,
           :y => mean_errors,
           :xlab => '# of workers',
           :ylab => 'Sum Squared Error')
    r.plot(:x => mean_views,
           :y => mean_errors,
           :xlab => '# views',
           :ylab => 'Sum Squared Error')
    $stdin.gets.chomp
    
  end

  # Given a list of image counts, aggregate them and scores them
  def get_image_scores(count_list)
    counts = Hash.new { |h, k| h[k]=[0, 0, 0, 0] }

    # Aggregate the counts
    for cur_counts in count_list
      cur_counts.each do |img, count|
        for i in (0..3) do
          counts[img][i] += count[i]
        end
      end
    end

    # Calculate the score
    scores = Hash.new { |h, k| h[k] = 0.0 }
    total_views = 0.0
    counts.each do |img, count|
      if count[0] == 0 or count[1] == 0
        next
      end

      score = count[2].to_f / count[0] - count[3].to_f / count[1]
      score = score.round(3)
      scores[img] = score
      total_views += count[0] + count[1]
    end

    return scores, total_views / counts.length / 2
  end

  # Calculates the sum squared error between two sets of image scores
  def calculate_error(tru_scores, meas_scores)
    error = 0.0
    tru_scores.each do |image, tscore|
      mscore = meas_scores[image]
      error += (tscore - mscore) ** 2
    end

    return error
  end

  def get_mean_error(tru_scores, count_list, n_workers, n_samples, rng)
    mean_error = 0.0
    mean_views = 0.0
    for i in (0...N_SAMPLES) do
      cur_scores, view_counts = get_image_scores(
        count_list.sample(n_workers, random: rng))
      mean_error += calculate_error(tru_scores, cur_scores)
      mean_views += view_counts
    end
    return mean_error / N_SAMPLES, mean_views / N_SAMPLES
  end
end


