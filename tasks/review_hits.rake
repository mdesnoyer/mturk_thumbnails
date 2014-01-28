# Script that reviews hits and sends warnings to users and/or rejects them
#
# Author: Mark Desnoyer (desnoyer@neon-lab.com)
# Copyright 2013 Neon Labs
require 'aws-sdk'
require 'debugger'
require 'rturk'

namespace :review_hits do
  warning_messages = [
    "It appears that you are not doing the selection task correctly. It looks like you are clicking randomly instead of quickly selecting the image you would prefer. I'll accept this batch of work, but next time, please try to complete the task as asked.",
    "You still seem to be doing the task incorrectly. Please select those images you would prefer. I'll accept this batch, but the next time your work looks bad, I'll start rejecting the HITS."
                      ]
                      

  def HandleBadAssignment(assignment, warning_level)
    if warning_level < 2
      assignment.approve
    else
      assignment.reject("I'm sorry, but after being warned, it still looks like you are not doing the task correctly. You should select the images you would prefer to find more about.")
    end
  end

  task :sandbox => :environment do
    Rake::Task['extend_hits:default'].invoke('true')
  end

  task :default, [:sandbox] => [:environment] do |t, args|
    # Setup the arguments
    args.with_defaults(:sandbox => 'false')
    sandbox = args[:sandbox] == 'true'

    # Connect to the production database
    ActiveRecord::Base.establish_connection(
      ActiveRecord::Base.configurations[:remote_production])

    # Connect to mechanical turk
    RTurk.setup(ENV['AWS_ACCESS_KEY'],
                ENV['AWS_SECRET_KEY'],
                :sandbox => sandbox)

    hits = RTurk::Hit.all_reviewable

    puts "#{hits.size} reviewable hits. \n"

    unless hits.empty?
      puts "Reviewing all assignments"

      hits.each do |hit|
        hit_details = RTurk::GetHIT(:hit_id => hit.id)
        stimset = QuestionURL2Stimset(hit_details.question_external_url)
        hit.assignments.each do |assignment|
          if assignment.status != 'Submitted'
            # The assignment is not ready to review
            next
          end

          reason = UserRejection.select(:reason).where(
            worker_id: assignment.worker_id, stimset: stimset).map(&:reason)[0]
          if reason.nil?
            # We didn't reject this user
            assignment.approve
            next
          end

          debugger

          warning_info = RejectionWarnings.select(:id, :last_warning_time, :last_warning_level).where(worker_id: assignment.worker_id)
          if warning_info.nil?
            # First time to warn the user
            RejectionWarnings.create(worker_id: assignment.worker_id,
                                     last_warning_level: 0,
                                     last_warning_time: Time.now())
            cur_level = 0
          else
            # See if we've already warned the user recently
            if warning_info.last_warning_time > assignment.submit_time
              HandleBadAssignment(assignment, 0)
              next
            end

            # Record the next level of warning
            cur_level = warning_info.last_warning_level + 1
            RejectionWarnings.update(warning_info.id,
                                     :last_warning_level => cur_level,
                                     :last_warning_time => Time.now())
          end

          # Send the actual warning
          if cur_level < warning_messages.length
            RTurk::NotifyWorkers(:worker_ids => [assignment.worker_id],
                                 :message_text => warning_messages[cur_level],
                                 :subject => "Problem with HIT #{hit.id}")
          else
            HandleBadAssignment(assignment, cur_level)
          end
        end
      end
    end
  end
end