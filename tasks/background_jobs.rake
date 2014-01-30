# Defines some background tasks that we'd want to run regularily
#
# Author: Mark Desnoyer (desnoyer@neon-lab.com)
# Copyright 2013 Neon Labs

namespace :background_jobs do
  task :run_review_pipeline => :environment do

    Rake::Task['calculate_scores:default'].invoke
    #Rake::Task['review_hits:default'].invoke('false')
    Rake::Task['extend_hits:default'].invoke('false')

  end

end
