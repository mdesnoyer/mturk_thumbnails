# Script that plots the reaction time vs. the prob of the click
# distribution being random.
#
# Module that contains utilities for filtering out bad data from the turk job.
# Copyright 2013 Neon Labs

require 'turk_filter'
require 'securerandom'

begin
  require 'rsruby'
rescue LoadError
end

$N_SAMPLES = 500

namespace :plot_prand do
  task :prod => :environment do
    # Connect to the production database
    ActiveRecord::Base.establish_connection(
      ActiveRecord::Base.configurations[:remote_production])

    Rake::Task['plot_prand:default'].invoke

    # Close connection to the production database
    ActiveRecord::Base.establish_connection(ENV['RAILS_ENV']) 
  end

  task :default => :environment do
    calculator = TurkFilter::TooRandom.new(
      Rake.application.original_dir + '/config/score_prob.csv',
      Rake.application.original_dir + '/config/g_stats.csv',
      0.10)

    filters = [TurkFilter::TrialDuplicate.new,
               TurkFilter::TrialTooSlow.new]

    # Calculate the stats
    reaction_times = []
    probs = []
    jobs = ImageChoice.select('distinct worker_id, substring(stimset_id from \'stimuli_[0-9]+\') as stim').limit($N_SAMPLES).where("stimset_id like 'stimuli_%'").map{
      |c| [c.worker_id, c.stim]
    }
    jobs.each do |worker, stim|
      trials = ImageChoice.where('worker_id = ? and stimset_id like ?',
                                 worker, "#{stim}\\_%").all
      if trials.length == 0
        next
      end

      filters.each do |filter|
        trials = filter.filter_trials(trials)
      end

      time_sum = 0
      valid_trials = 0
      for trial in trials
        if not trial.reaction_time.nil?
          time_sum += trial.reaction_time
          valid_trials += 1
        end
      end
    
      if valid_trials > 0
        reaction_times << time_sum.to_f / valid_trials
        probs << calculator.calculate_p_random(trials)
      end
    end

    # Plot them
    r = RSRuby.instance
    r.plot(:x => reaction_times,
           :y => probs,
           :xlab => 'Avg. Reaction Time (ms)',
           :ylab => 'P(random)')
    $stdin.gets.chomp
  end

end
