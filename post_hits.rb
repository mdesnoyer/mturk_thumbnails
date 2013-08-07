require 'rturk'
require 'fileutils'
require 'csv'
require 'Clipboard'

# hit_assignments = ARGV[0]
# payment_amount  = ARGV[1]
# image_sets      = ARGV[2..-1]

def all_children_except(parent_folder, extra_regex = '')
    regex = '^\.'
    regex += '|' + extra_regex unless extra_regex.empty?
    Dir.entries(parent_folder).reject { |file| file =~ Regexp.new(regex) }.map { |file| File.expand_path(file, parent_folder) }
end

def post_task(hit_title, unique_id)
  # RTurk.setup("AKIAJ5G2RZ6BDNBZ2VBA", "d9Q9abhaUh625uXpSrKElvQ/DrbKsCUAYAPaeVLU", :sandbox => true)
  
  RTurk.setup("AKIAJ5G2RZ6BDNBZ2VBA", "d9Q9abhaUh625uXpSrKElvQ/DrbKsCUAYAPaeVLU")
  
  hit = RTurk::Hit.create(:title => "Choose an Online a Video! [#{unique_id}]") do |hit|
    hit.assignments = $hit_assignments
    hit.description = 'Choose an Online a Video!'
    hit.question("http://gentle-escarpment-8454.herokuapp.com/keep_instructions/#{unique_id}", :frame_height => 1000)
    hit.question("My Survey")
    hit.reward = $payment_amount
    hit.lifetime = 86400
    hit.qualifications.add :approval_rate, { :gt => 80 }
  end
  
  # Clipboard.copy hit.url
end

$hit_assignments = 1
$payment_amount  = 1.00

images_path     = "/Users/deborahjohnson/Dropbox/mturk_thumbnails/app/assets/images"
text_files_main = "/Users/deborahjohnson/Dropbox/mturk_thumbnails/config"
parent_folder   = "/Users/deborahjohnson/Desktop/new_image_sets/"

image_sets = []

if all_children_except(parent_folder).any? { |child_dir| child_dir =~ /.jpg/ }
  image_sets << {:original_path => parent_folder, :folder_name => File.basename(parent_folder)}
else
  all_children_except(parent_folder).each do |folder|
    image_sets << {:original_path => folder, :folder_name => File.basename(folder)}
  end
end

image_sets.each do |folder|
  folder[:file_names] = []
  all_image_paths = all_children_except(folder[:original_path])
  all_image_paths.each do |image|
    folder[:file_names] << File.basename(image)
  end
  r = Random.new
  unique_id = r.rand(100..100000)
  # New images folder name
  folder[:new_name]  = "stimuli#{unique_id}"
  folder[:unique_id] = unique_id
  # New images folder complete path
  images_folder_path = "#{images_path}/#{folder[:new_name]}"
  # Move folder from original location into main images folder in app
  FileUtils.mv(folder[:original_path], images_path)
  # Rename folder
  FileUtils.mv("#{images_path}/#{folder[:folder_name]}", images_folder_path)
  # cd to main folder for text files
  FileUtils.cd(text_files_main)
  # Make a new folder that will contain the text file for this stimset
  FileUtils.mkdir("#{unique_id}")
  folder[:text_file_folder] = "#{text_files_main}/#{unique_id}"
  folder[:text_file_path]   = "#{folder[:text_file_folder]}/stimuli.csv"
  CSV.open(folder[:text_file_path], "w") do |csv|
    (1..108).each do |i|
      csv << ["#{i}", "#{folder[:file_names][i]}"]
    end
  end
end

# ****RUN BASH SCRIPT****

Dir.chdir("/Users/deborahjohnson/Dropbox/mturk_thumbnails")
`./heroku_deploy.sh`

# Post HITs
image_sets.each do |set|
  post_task(set[:hit_title], set[:unique_id])
end