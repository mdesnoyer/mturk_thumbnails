#!/usr/bin/env ruby
require 'rturk'
require 'fileutils'
require 'csv'
require 'clipboard'
require 'securerandom'
require 'trollop'

def all_children_except(parent_folder, extra_regex = '')
    regex = '^\.'
    regex += '|' + extra_regex unless extra_regex.empty?
    Dir.entries(parent_folder).reject { |file| file =~ Regexp.new(regex) }.map { |file| File.expand_path(file, parent_folder) }
end

def post_task(hit_title, unique_id, payment_amount, hit_assignments, sandbox)

  RTurk.setup("AKIAJ5G2RZ6BDNBZ2VBA",
              "d9Q9abhaUh625uXpSrKElvQ/DrbKsCUAYAPaeVLU",
              :sandbox => sandbox)
  
  hit = RTurk::Hit.create(:title => "Choose an Online a Video! [#{unique_id}]") do |hit|
    hit.assignments = hit_assignments
    hit.description = 'Choose an Online a Video!'
    hit.question("http://gentle-escarpment-8454.herokuapp.com/keep_instructions/#{unique_id}", :frame_height => 1000)
    hit.question("My Survey")
    hit.reward = payment_amount
    hit.lifetime = 86400
    hit.qualifications.add :approval_rate, { :gt => 80 }
  end
  
  # Clipboard.copy hit.url
  puts "Job on mturk at: #{hit.url}"
end

# Define the command line arguments
opts = Trollop::options do
  opt :pay, "Payment amount", :type => :float, :default => 1.00
  opt :sandbox, "If set, loads hit to a sandbox instead of production"
  opt :assignments, "Number of assignments", :type => :int, :default =>1
  opt :input, "List of directories containing new stimuli sets",
    :type => :strings
  opt :output, "Path to the app. Defaults to the current directory", 
    :type => :string
end

# Default the app dir to the current directory
if opts[:output].nil?
  opts[:output] = Dir.pwd
end
Dir.chdir(opts[:output])

image_sets = []
opts[:input].each do |folder|
  image_sets << {:original_path => folder,
    :folder_name => File.basename(folder)}
end

image_sets.each do |folder|

  # Get the list of images in the folder
  folder[:file_names] = []
  all_image_paths = all_children_except(folder[:original_path])
  all_image_paths.each do |image|
    folder[:file_names] << File.basename(image)
  end
  
  unique_id = SecureRandom.hex(10)

  # New images folder name
  folder[:new_name]  = "#{folder[:folder_name]}_#{unique_id}"
  folder[:unique_id] = unique_id

  puts "Creating new stimuli set from #{folder[:original_path]} as #{folder[:new_name]}"

  # New images folder complete path
  images_path = "#{opts[:output]}/app/assets/images"
  images_folder_path = "#{images_path}/#{folder[:new_name]}"

  # Copy folder from original location into main images folder in app
  FileUtils.cp_r(folder[:original_path], images_path,
                 :remove_destination => true)
  FileUtils.mv("#{images_path}/#{folder[:folder_name]}",
               images_folder_path)
  `git add #{images_folder_path}`

  # Create the text file for this stimset
  text_files_main = "#{opts[:output]}/config"
  folder[:text_file_folder] = "#{text_files_main}/#{folder[:new_name]}"
  FileUtils.mkdir_p("#{folder[:text_file_folder]}")
  folder[:text_file_path]   = "#{folder[:text_file_folder]}/stimuli.csv"
  CSV.open(folder[:text_file_path], "w") do |csv|
    (1..108).each do |i|
      csv << ["#{i}", "#{folder[:file_names][i-1]}"]
    end
  end

  `git add #{folder[:text_file_path]}`
end

# ****RUN BASH SCRIPT****
`./heroku_deploy.sh`

# Post HITs
image_sets.each do |set|
  post_task(set[:hit_title], set[:unique_id], opts[:pay], opts[:assignments],
            opts[:sandbox])
end
