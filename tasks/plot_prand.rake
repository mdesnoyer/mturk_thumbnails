# Script that plots the reaction time vs. the prob of the click
# distribution being random.
#
# Module that contains utilities for filtering out bad data from the turk job.
# Copyright 2013 Neon Labs

require 'turk_filter'
require 'debugger'
require 'rsruby'
require 'securerandom'

$AWS_ACCESS_KEY='AKIAJ5G2RZ6BDNBZ2VBA'
$AWS_SECRET_KEY='d9Q9abhaUh625uXpSrKElvQ/DrbKsCUAYAPaeVLU'

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
    jobs = ImageChoice.select('distinct worker_id, stimset_id').limit($N_SAMPLES).map{
      |c| [c.worker_id, c.stimset_id]
    }
    jobs.each do |worker, stim|
      trials = ImageChoice.where(:worker_id => worker, :stimset_id => stim)
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

    # For now, don't put the graph up on S3
    return

    unique_id = SecureRandom.hex(10)
    graph_file = "p_random_vs_reaction_time_#{unique_id}.png"
    
    s3 = AWS::S3.new(access_key_id:$AWS_ACCESS_KEY ,
                     secret_access_key: $AWS_SECRET_KEY)
    bucket = s3.buckets['neon-graphs']
    bucket.objects[graph_file].write(chart.fetch,
                                     :acl => :public_read)
  
    puts 'Your graph is available at:'
    puts "https://neon-graphs.s3.amazonaws.com/#{graph_file}"
  end

end
