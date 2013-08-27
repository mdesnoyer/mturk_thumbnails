# Script that plots the reaction time vs. the prob of the click
# distribution being random.
#
# Module that contains utilities for filtering out bad data from the turk job.
# Copyright 2013 Neon Labs

require 'turk_filter'
require 'gchart'
require 'debugger'

$AWS_ACCESS_KEY='AKIAJ5G2RZ6BDNBZ2VBA'
$AWS_SECRET_KEY='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'

task plot_prand: :environment do

  calculator = TurkFilter::TooRandom.new(
    Rake.application.original_dir + '/config/score_prob.csv',
    Rake.application.original_dir + '/config/g_stats.csv',
    0.10)

  filter = TurkFilter::TrialDuplicate.new

  # Calculate the stats
  reaction_times = []
  probs = []
  jobs = ImageChoice.select('distinct worker_id, stimset_id').map{
    |c| [c.worker_id, c.stimset_id]
  }
  jobs.each do |worker, stim|
    trials = ImageChoice.where(:worker_id => worker, :stimset_id => stim)
    if trials.length == 0
      next
    end

    trials = filter.filter_trials(trials)

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

  chart = Gchart.new(
    :type => 'scatter',
    :data => [reaction_times, probs],
    :size => '500x500',
    :point_size => 2,
    :title => 'P(random) vs. Avg. Reaction Time (ms)',                         
    :axis_with_labels => [['x'],['y']])

  s3 = AWS::S3.new(access_key_id:$AWS_ACCESS_KEY ,
                   secret_access_key: $AWS_SECRET_KEY)
  bucket = s3.buckets['neon-graphs']
  bucket.objects['p_random_vs_reaction_time.png'].write(chart.fetch,
                                                        :acl => :public_read)

  puts 'https://neon-graphs.s3.amazonaws.com/p_random_vs_reaction_time.png'
end
