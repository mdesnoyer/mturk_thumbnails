# Defines some background tasks that we'd want to run regularily
#
# Author: Mark Desnoyer (desnoyer@neon-lab.com)
# Copyright 2013 Neon Labs

namespace :background_jobs do
  task :calculate_scores_and_extend_hits => :environment do

    Rake::Task['calculate_scores:default'].invoke
    Rake::Task['extend_hits:default'].invoke('false')

  end

end
