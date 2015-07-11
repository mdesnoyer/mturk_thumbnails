# Script that reviews hits and sends warnings to users and/or rejects them
#
# Author: Mark Desnoyer (desnoyer@neon-lab.com)
# Copyright 2013 Neon Labs
require 'aws-sdk'
require 'rturk'

begin
  require 'debugger'
rescue LoadError
end

namespace :review_hits do
  warning_messages = [
    "Hi,\n\nIt appears that you are not doing the selection task correctly. It looks like you are clicking randomly instead of quickly selecting the image you would prefer. I'll accept this batch of work, but next time, please try to complete the task as asked.",
    "Hi,\n\nYou still seem to be doing the task incorrectly. Please select those images you would prefer. I'll accept this batch, but the next time your work looks bad, I'll start rejecting the HITS."
                      ]
                      

  def HandleBadAssignment(assignment, warning_level)
    if warning_level < 2
      RTurk::ApproveAssignment(:assignment_id => assignment.id)
    else
      puts "Rejecting assignment #{assignment.id} from worker #{assignment.worker_id}"
      RTurk::RejectAssignment(:assignment_id => assignment.id,
                              :feedback => "I'm sorry, but after being warned, it still looks like you are not doing the task correctly. You should select the images you would prefer to explore more.")
    end
  end

  task :sandbox => :environment do
    Rake::Task['review_hits:default'].invoke('true')
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

    xml_data = RTurk::GetReviewableHITs(:page_number => 1, :page_size => 30, :sort_property => 'CreationTime', :sort_direction => 'Descending')

    hit_ids = []

    xml_data.hit_ids.each do |hit|
     hit_ids << hit
    end

    hits = []

    hit_ids.each do |hit|
     hits << RTurk::GetHIT(:hit_id => hit)
    end

    puts "#{hits.size} reviewable hits. \n"

    # Get the last time that the user_rejection table was uploaded
    ActiveRecord::Base.default_timezone = :utc # Database stores in UTC
    last_user_rejection_time = UserRejection.maximum(:updated_at)

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

          # If the assignment was submitted after our last database
          # update, we can't draw a conclusion yet
          if last_user_rejection_time < assignment.submitted_at
            next
          end


          reason = UserRejection.select(:reason).where(
            worker_id: assignment.worker_id, stimset: stimset).map(&:reason)[0]
          if reason.nil?
            # We didn't reject this user
            RTurk::ApproveAssignment(:assignment_id => assignment.id)
            next
          end

          warning_info = RejectionWarning.select(
            [:id, :last_warning_time, :last_warning_level]).where(
            worker_id: assignment.worker_id)[0]

          if warning_info.nil?
            # First time to warn the user
            RejectionWarning.create(worker_id: assignment.worker_id,
                                    last_warning_level: 0,
                                    last_warning_time: Time.now())
            cur_level = 0
          else
            # See if we've already warned the user recently
            if warning_info.last_warning_time > assignment.submitted_at
              HandleBadAssignment(assignment, 0)
              next
            end

            # Record the next level of warning
            cur_level = warning_info.last_warning_level + 1
            RejectionWarning.update(warning_info.id,
                                    :last_warning_level => cur_level,
                                    :last_warning_time => Time.now())
          end

          # Send the actual warning
          if cur_level < warning_messages.length
            puts "Warning worker: #{assignment.worker_id}"
            RTurk::NotifyWorkers(:worker_ids => [assignment.worker_id],
                                 :message_text => warning_messages[cur_level],
                                 :subject => "Problem with HIT #{hit.title}")
          end
          HandleBadAssignment(assignment, cur_level)
        end
      end
    end
  end
end
