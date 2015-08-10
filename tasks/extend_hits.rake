# Script that extends any hits where we didn't get enough data for
# that stimuli set.
#
# Author: Mark Desnoyer (desnoyer@neon-lab.com)
# Copyright 2013 Neon Labs
require 'aws-sdk'
require 'hit_utils'
require 'mail'
require 'net/smtp'
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

    RTurk::SearchHITs.create(:page_size => 110, :sort_by => {:created_at => :descending}).hits.each do |hit|
      hit_details = RTurk::GetHIT(
        :hit_id => hit.id,
        :include_assignment_summary => true)
      stimset = QuestionURL2Stimset(hit_details.question_external_url)
      hits[stimset] << hit_details
    end
    return hits
  end

  def GetAvgValidResponses(stimset)
    # Retrieves the minimum number of valid responses for a given stimset
    response = ImageScore.select('avg((valid_keeps + valid_returns)/2) as val').where(:stimset => stimset)[0]

    if response.nil?
      return 0
    end
    return response.val.to_i
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
    RTurk.setup(ENV['MTURK_ACCESS_KEY_ID'],
                ENV['MTURK_SECRET_ACCESS_KEY'],
                :sandbox => sandbox)

    GetHitsByStimset().each do | stimset, hits |
      if AnyHitRunning(hits)
        puts "HIT #{stimset} is still running"
        next
      end

      avgValidResponses = GetAvgValidResponses(stimset)
      minimum_valid_responses = 40

      if avgValidResponses > minimum_valid_responses
        # then it's finished running and all is well
        puts "HIT #{stimset} has at least #{minimum_valid_responses} valid responses -- it's complete! Disposing of hit"
        hits.map(&:dispose!)
        next
      else
        puts "HIT #{stimset} only has #{avgValidResponses}, that is not enough. Minimum is currently set to #{minimum_valid_responses}"
      end

      # Now extend the hit
      newAssignments = [((24-avgValidResponses) / 4.0).floor, 1].max
      timeLeft = (hits[0].expires_at - Time.now)
      timeExtension = 60
      if timeLeft <  86400
        timeExtension = 172800
      end
      puts "Extending #{stimset} by #{newAssignments} during #{timeExtension}"
      begin
        RTurk::ExtendHIT(:hit_id => hits[0].hit_id,
                         :seconds => timeExtension,
                         :assignments => newAssignments)
      rescue RTurk::InvalidRequest => e
        puts "Error extending the HIT: #{e.message}"

        # Send the admin an e-mail saying that there's a problem with
        # Mechanical Turk. Odds are we ran out of money.
        mail = Mail.new do
          from    'mturk@neon-lab.com'
          to      'desnoyer@neon-lab.com'
          subject 'Error extending HIT'
          body    "Problem with hit #{hits[0].hit_id}:\n#{e.message}"
        end
        Net::SMTP.start('aspmx.l.google.com',
                        25,
                        'neon-lab.com') do |smtp|
          smtp.send_message(mail.to_s,
                            'mturk@neon-lab.com',
                            'desnoyer@neon-lab.com')
        end
        break
      end
    end

    # Close connection to the production database
    #ActiveRecord::Base.establish_connection(ENV['RAILS_ENV'])
  end

end
