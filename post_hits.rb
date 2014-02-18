#!/usr/bin/env ruby
require 'rubygems'
require 'aws-sdk'
require 'rturk'
require 'fileutils'
require 'csv'
require 'clipboard'
require 'securerandom'
require 'trollop'

$STAGING_APP='gentle-escarpment-8454-staging'
$PROD_APP='gentle-escarpment-8454'

AWS.config(
  :access_key_id => ENV['AWS_ACCESS_KEY_ID'], 
  :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY']
)

def all_children_except(parent_folder, extra_regex = '')
    regex = '^\.'
    regex += '|' + extra_regex unless extra_regex.empty?
    Dir.entries(parent_folder).reject { |file| file =~ Regexp.new(regex) }.map { |file| File.expand_path(file, parent_folder) }
end

def post_tasks(job_names, bucket_name, payment_amount, hit_assignments,
               sandbox)

  RTurk.setup(ENV['MTURK_ACCESS_KEY_ID'],
              ENV['MTURK_SECRET_ACCESS_KEY'],
              :sandbox => sandbox)

  if sandbox then
    app_base=$STAGING_APP
  else
    app_base=$PROD_APP
  end
  url_base = "https://#{app_base}.herokuapp.com"

  hittype = RTurk::RegisterHITType.create(:title => "Choose an Online a Video!") do |hit|
    hit.description = 'Choose an Online a Video!'
    hit.reward = payment_amount
    hit.duration = 3600
    hit.auto_approval = 172800 # auto approves the job 2 days after submission
    hit.keywords = "images, game, psychology, video, fast"
    hit.qualifications.add :approval_rate, { :gt => 80 }
    hit.qualifications.add :country, {:eql => 'US' }
  end
  
  job_names.each do |job_name|
    hit = RTurk::Hit.create() do |hit|
      hit.assignments = hit_assignments
      hit.hit_type_id = hittype.type_id
      hit.lifetime = 2592000
      hit.question("#{url_base}/experiment",
                   :job => job_name,
                   :s3_bucket => bucket_name,
                   :frame_height => 1000)

        
    end
    # Clipboard.copy hit.url
    puts "Job on mturk at: #{hit.url}"
  end
end

# Define the command line arguments
opts = Trollop::options do
  opt :pay, "Payment amount", :type => :float, :default => 1.00
  opt :sandbox, "If set, loads hit to a sandbox instead of production"
  opt :assignments, "Number of assignments", :type => :int, :default =>1
  opt :input, "List of directories containing new stimuli sets",
    :type => :strings
  opt :s3bucket, "Bucket name to host the images", :type => :string,
    :default => "mturk_bday_thumbs_9lwe9"
end

image_sets = []
opts[:input].each do |folder|
  image_sets << {:original_path => folder,
    :folder_name => File.basename(folder)}
end

image_sets.each do |folder|
  unique_id = SecureRandom.hex(10)
  folder[:unique_id] = unique_id
  folder[:new_name] = "#{folder[:folder_name]}_#{unique_id}"

  # Upload the images to the S3 bucket
  puts("Uploading images from #{folder[:original_path]} to S3 bucket #{opts[:s3bucket]}")
  s3 = AWS::S3.new
  folder[:file_names] = []
  all_image_paths = all_children_except(folder[:original_path])
  all_image_paths.each do |image_path|
    key = File.basename(image_path)
    folder[:file_names] << key
    s3obj = s3.buckets[opts[:s3bucket]].objects[key]
    if !s3obj.exists? then
        s3obj.write(:file => image_path,
                    :acl => :public_read)
    end
  end

  # Create the text file for this stimset
  text_file_name = "#{folder[:new_name]}_stimuli.csv"
  csv_string = CSV.generate do |csv|
    (1..108).each do |i|
      csv << ["#{i}", "#{folder[:file_names][i-1]}"]
    end
  end

  puts("Writing #{text_file_name} to S3")
  s3.buckets[opts[:s3bucket]].objects[text_file_name].write(
    csv_string,
    :acl => :public_read)

end

# Post HITs
job_names = []
image_sets.each do |set|
  job_names << set[:new_name]
end
post_tasks(job_names, opts[:s3bucket], opts[:pay], opts[:assignments],
           opts[:sandbox])

