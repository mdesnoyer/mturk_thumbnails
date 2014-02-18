# Script that plots the reaction time vs. the maximum number of times
# the same slot was chosen.
#
# Author: Mark Desnoyer (desnoyer@neon-lab.com)
# Copyright 2013 Neon Labs

require 'turk_filter'
require 'securerandom'

begin
  require 'rsruby'
rescue LoadError
end

$N_SAMPLES = 500

namespace :plot_same_slot_count do
  task :prod => :environment do
    # Connect to the production database
    ActiveRecord::Base.establish_connection(
      ActiveRecord::Base.configurations[:remote_production])

    Rake::Task['plot_same_slot_count:default'].invoke

    # Close connection to the production database
    ActiveRecord::Base.establish_connection(ENV['RAILS_ENV']) 
  end

  task :default => :environment do

    filters = [TurkFilter::TrialDuplicate.new,
               TurkFilter::TrialTooSlow.new]

    # Calculate the stats
    reaction_times = []
    same_counts = []
    jobs = ImageChoice.select('distinct worker_id, substring(stimset_id from \'stimuli_[0-9]+\') as stim').limit($N_SAMPLES).where("stimset_id like 'stimuli_%'").map{
      |c| [c.worker_id, c.stim]
    }
    jobs.each do |worker, stim|
      trials = ImageChoice.where('worker_id = ? and stimset_id like ?',
                                 worker, "#{stim}\\_%").order(:trial).all
      if trials.length == 0
        next
      end

      filters.each do |filter|
        trials = filter.filter_trials(trials)
      end

      time_sum = 0
      valid_trials = 0
      last_slot = nil
      same_slot_count = 0
      max_same_slot = 0
      for trial in trials
        if not trial.reaction_time.nil?
          time_sum += trial.reaction_time
          valid_trials += 1

          cur_slot = nil
          if trial.chosen_image == trial.image_one
            cur_slot = 1
          elsif trial.chosen_image == trial.image_two
            cur_slot = 2
          elsif trial.chosen_image == trial.image_three
            cur_slot = 3
          end
          
          if last_slot == cur_slot
            same_slot_count += 1
            if same_slot_count > max_same_slot
              max_same_slot = same_slot_count
            end
          else
            same_slot_count = 0
          end
          last_slot = cur_slot
        end
      end
    
      if valid_trials > 0
        reaction_times << time_sum.to_f / valid_trials
        same_counts << max_same_slot
      end
    end

    # Plot them
    r = RSRuby.instance
    r.plot(:x => reaction_times,
           :y => same_counts,
           :xlab => 'Avg. Reaction Time (ms)',
           :ylab => 'Max same choice')
    #r.hist(:x => same_counts,
    #       :breaks => 50,
    #       :plot => true)
    $stdin.gets.chomp
  end

end
