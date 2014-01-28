# Script that extends any hits where we didn't get enough data for
# that stimuli set.
#
# Author: Mark Desnoyer (desnoyer@neon-lab.com)
# Copyright 2013 Neon Labs
require 'aws-sdk'
require 'hit_utils'
require 'rturk'

begin
  require 'debugger'
rescue LoadError
end

namespace :extend_hits do
  def AnyHitRunning(hits)
    # Returns true if any of the hits in a list are still running
    for hit in hits
      if (hit.assignments_pending_count > 0 or 
          hit.assignments_available_count > 0)
        return true
      end
    end
    return false
  end

  def GetHitsByStimset()
    # Contacts mechanical turk to get the hits for each stimset
    # Returns: {stimset_id => [hits]}
    hits = Hash.new { |h, k| h[k]=[] }
    
    RTurk::SearchHITs.create(:sort_by => {:created_at => :desc}).hits.each do |hit|
      hit_details = RTurk::GetHIT(
        :hit_id => hit.id,
        :include_assignment_summary => true)
      stimset = QuestionURL2Stimset(hit_details.question_external_url)
      hits[stimset] << hit_details
    end
    return hits
  end

  def GetMinValidResponses(stimset)
    # Retrieves the minimum number of valid responses for a given stimset
    return (ImageScore.where(:stimset => stimset).minimum(:valid_returns) ||
            0)
  end

  task :sandbox => :environment do
    Rake::Task['extend_hits:default'].invoke('true')
  end

  task :default, [:sandbox] => [:environment] do |t, args|
    # Setup the arguments
    args.with_defaults(:sandbox => 'false')
    sandbox = args[:sandbox] == 'true'

    # Connect to the remote database
    if sandbox
      ActiveRecord::Base.establish_connection(
        ActiveRecord::Base.configurations[:remote_staging])
    else
      ActiveRecord::Base.establish_connection(
        ActiveRecord::Base.configurations[:remote_production])
    end

    # Connect to mechanical turk
    RTurk.setup(ENV['AWS_ACCESS_KEY'],
                ENV['AWS_SECRET_KEY'],
                :sandbox => sandbox)

    GetHitsByStimset().each do | stimset, hits |
      if AnyHitRunning(hits)
        puts "HIT #{stimset} is still running"
        next
      end

      minValidResponses = GetMinValidResponses(stimset)
      if minValidResponses > 100
        next
      end

      # Now extend the hit
      newAssignments = ((100-minValidResponses) / 3.0).floor
      timeExtension = (Time.now - hits[0].expires_at)
      timeExtension = (timeExtension * 24 * 60 * 60 + 605000).to_i
      if timeExtension < 0
        timeExtension = 60
      end
      puts "Extending #{stimset} by #{newAssignments} during #{timeExtension}"
      RTurk::ExtendHIT(:hit_id => hits[0].hit_id,
                       :seconds => timeExtension,
                       :assignments => newAssignments)
    end

    # Close connection to the production database
    #ActiveRecord::Base.establish_connection(ENV['RAILS_ENV'])
  end

end
