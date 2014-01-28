# Module that contains utilities for filtering out bad data from the turk job.
#
# Authors: Mark Desnoyer (desnoyer@neon-lab.com)
#          Deb Johnson (deb@neon-lab.com)
# Copyright Neon Labs 2013

require 'csv'
require 'interpolator'
require 'logger'

module TurkFilter
  # Set of constants used to describe why rejections took place
  module RejectReason
    NONE = nil
    TOO_FAST = 'Reaction was too fast'
    TOO_SLOW = 'Reaction was too slow'
    DUPLICATE = 'Duplicate'
    TOO_RANDOM = 'Worker was too random'
    SAME_SLOT = 'Worker clicked the same slot too many times in a row'
  end

  logger = Logger.new(STDOUT)
  logger.level = Logger::WARN

  @pre_trial_filters = nil
  @post_trial_filters = nil
  @worker_filters = nil

  def TurkFilter.load_filters
    if @pre_trial_filters.nil?
      @pre_trial_filters = [TrialDuplicate.new,
                           TrialTooSlow.new]
    end

    if @post_trial_filters.nil?
      @post_trial_filters = [TrialTooFast.new]
    end

    if @worker_filters.nil?
      @worker_filters = [
        TooManyClicksInSameSlot.new(15),
        TooRandom.new(
          Rake.application.original_dir + '/config/score_prob.csv',
          Rake.application.original_dir + '/config/g_stats.csv',
          0.15)
      ]
    end
  end

  # Function that returns the filtered trials for a given job.
  # The database is accessed to determine this valid jobs.
  #
  # Inputs:
  # worker_id - Worker id of the worker doing the job
  # stimset_id - Id of the stimuli set processed.
  #
  # Outputs:
  # A hash with the following entries:
  # trials - Sequence of valid trial rows from the database
  # worker_rejection - Reason that the worker was rejected
  # trial_rejections - Map of rejection reason -> # of trials rejected that
  #                    way. Note, a trial can only be rejected for one reason.
  def TurkFilter.get_filtered_trials(worker_id, stimset_id)
    retval = {
      'trials' => [],
      'worker_rejection' => RejectReason::NONE,
      'trial_rejections' => {}
    }

    TurkFilter.load_filters()

    trials = ImageChoice.where(
      'worker_id = ? and stimset_id like ?',
      worker_id, "#{stimset_id}\\_%").order(:trial).all


    # Run the filters on the trials
    @pre_trial_filters.each do |filter|
      start_trials = trials.length
      trials = filter.filter_trials(trials)
      n_filtered = start_trials - trials.length
      if n_filtered > 0
        retval['trial_rejections'][filter.reason()] = n_filtered
      end
    end

    # Filter the worker to decide if the resulting
    # dataset is valid
    @worker_filters.each do |filter|
      if not filter.is_valid(trials)
        retval['worker_rejection'] = filter.reason
        return retval
      end
    end
    

    # Run the filters on the trials
    @post_trial_filters.each do |filter|
      start_trials = trials.length
      trials = filter.filter_trials(trials)
      n_filtered = start_trials - trials.length
      if n_filtered > 0
        retval['trial_rejections'][filter.reason()] = n_filtered
      end
    end


    retval['trials'] = trials
    return retval
  end

  # Abstract class that will filter a sequence of trials
  class TrialFilter
    # Returns the filtered trials
    # Default implementation just iterates through and asks if the trial is
    # valid
    def filter_trials(trials)
      filtered_trials = []
      trials.each do |trial|
        if is_valid(trial)
          filtered_trials << trial
        end
      end
      return filtered_trials
    end

    # Returns true if the trial is valid
    def is_valid(trial)
      raise NotImplementedError
    end

    # Returns the reason associated with failing this filter
    def reason
      raise NotImplementedError
    end
  end

  # Filter the trial because the reaction time was too fast
  class TrialTooFast < TrialFilter
    def is_valid(trial)
      if trial.reaction_time.nil?
        return true
      end
      return trial.reaction_time > 400 # ms
    end

    def reason
      return RejectReason::TOO_FAST
    end
  end

  # Filter any situations where the trial was recorded more than once
  class TrialDuplicate < TrialFilter
    def filter_trials(trials)
      retval = []
      trials_seen = Set.new
      for trial in trials
        if not trials_seen.add?(trial.trial).nil?
          retval << trial
        end
      end
      return retval
    end

    def reason
      return RejectReason::DUPLICATE
    end
  end

  # The trial time was too slow, so something weird happened
  class TrialTooSlow < TrialFilter
    def is_valid(trial)
      if trial.reaction_time.nil?
        return true
      end
      return trial.reaction_time < 2000 # ms
    end

    def reason
      return RejectReason::TOO_SLOW
    end
  end

  # Abstract class that will filter a worker
  class WorkerFilter
    # Returns true if the worker created a valid dataset
    def is_valid(trials)
      raise NotImplementedError
    end

    # Returns the reason associated with failing this filter
    def reason
      raise NotImplementedError
    end
  end

  # Filters the worker if the distribution of scores is not
  # significantly different than random.
  class TooRandom < WorkerFilter
    # Loads data about the expected distribution from files.
    #
    # Inputs:
    # p_expected - Filename with the expected score distribution
    # g_prob - Filename with the probability of being greater than a gscore
    # thresh - Probability threshold to accept the worker
    def initialize(p_expected, g_prob, thresh)
      @thresh = thresh

      @p_expected = []
      CSV.foreach(p_expected) do |row|
        @p_expected << Float(row[1])
      end

      g_val = []
      g_p = []
      CSV.foreach(g_prob) do |row|
        g_val << Float(row[0])
        g_p << Float(row[1])
      end
      @g_prob = Interpolator::Table.new(g_val,g_p) do |tab|
        tab.style=Interpolator::Table::CUBIC
        tab.extrapolate=false
      end
    end

    def reason
      return RejectReason::TOO_RANDOM
    end

    def is_valid(trials)
      return calculate_p_random(trials) < @thresh
    end

    # Calculates the probability that the trials were generated by random
    def calculate_p_random(trials)
      # First calculate the scores
      scores = Hash.new
      trials.each do |trial|
        # Initialize the scores for the images in the trial if necessary
        if not scores.has_key?(trial.image_one)
          scores[trial.image_one] = 0
        end
        if not scores.has_key?(trial.image_two)
          scores[trial.image_two] = 0
        end
        if not scores.has_key?(trial.image_three)
          scores[trial.image_three] = 0
        end

        # Add a count for the selected image
        if trial.chosen_image != 'none' and trial.chosen_image != ''
          if trial.condition == 'KEEP'
            scores[trial.chosen_image] += 1
          else
            scores[trial.chosen_image] -= 1
          end
        end
      end

      # Determine the oberved probability of each score
      max_score = (@p_expected.length - 1)/2
      obs_count = Array.new(@p_expected.length, 0)
      scores.each do |image, score|
        if score > max_score or score < -max_score
          logger.error("Score for image #{image} is invalid. Throwing out all of the user's results.")
          return 1.0
        end
        obs_count[score + max_score] += 1
      end
      sum = obs_count.inject{|sum,x| sum + x}

      # Calculate the g statistic
      g = 0
      (0...obs_count.length).each do |i|
        if obs_count[i] > 0
          g += obs_count[i] * Math.log(Float(obs_count[i]) /
                                       (@p_expected[i]*sum))
        end
      end
      g *= 2

      # Determine the probability of have a g statistic >= to this
      # value by random
      return @g_prob.interpolate(g)
    end
  end

  # Filters a worker if they click the same slot too many times in a row
  class TooManyClicksInSameSlot < WorkerFilter
    # Inputs:
    #
    # thresh - threshold for the maximum number of times to click the
    # same spot and be safe.
    def initialize(thresh)
      @thresh = thresh
    end

    def reason
      return RejectReason::SAME_SLOT
    end

    def is_valid(trials)
      last_slot = nil
      same_slot_count = 0
      trials.each do |trial|
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
        else
          same_slot_count = 0
        end

        last_slot = cur_slot
        if same_slot_count > @thresh
          return false
        end
      end
      return true
    end
  end

end
