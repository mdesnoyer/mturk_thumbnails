require 'csv'
require 'open-uri/cached'

TRIALS_PATH  = "#{PADRINO_ROOT}/config/trials.txt"
TRIAL_COUNT = 144
RETURN_INSTRUCTIONS_START = TRIAL_COUNT + 1
TOTAL_TRIALS = TRIAL_COUNT * 2

def image_set_path
  "http://s3.amazonaws.com/#{@s3_bucket}/#{@job}_stimuli.csv"
end

def stimuli_folder_name
  "http://s3.amazonaws.com/#{@s3_bucket}"
end

def load_stimuli
  # Returns a image_id->image_file map
  puts(image_set_path)
  stream = open(image_set_path)
  data = stream.read
  stream.close

  retval = Hash.new
  CSV.parse(data) do |row|
    retval[row[0]] = row[1]
  end

  return retval
end

def get_image_list
  stims = load_stimuli

  return (1..stims.length).map { |i| stims[i.to_s] }
end

def load_trials
  trials_str = File.read(TRIALS_PATH)
  trial_lines = trials_str.split("\r")
  trial_lines[1..-1].map { |line| line.split("\t") }
end

def get_trial_sequence
  trials = load_trials.map{ |trial| trial.map{ |val| val.to_i } }
  # TODO(mdesnoyer): Remove this line after testing
  trials = trials[0..6]

  return trials.shuffle(random: Random.new(@worker_id.hash & 0xFFFF))
end

def get_amazon_url
  if @sandbox == '1'
    return 'https://workersandbox.mturk.com/mturk/externalSubmit'
  end
  return 'https://www.mturk.com/mturk/externalSubmit'
end

def read_params
  @s3_bucket = params[:s3_bucket]
  @job = params[:job]
  @assignment_id = params[:assignmentId] || params[:assignment_id]
  @hit_id = params[:hitId] || params[:hit_id]
  @worker_id = params[:workerId] || params[:worker_id]
  @n = (params[:n] ||  0).to_i
  @sandbox = params[:sandbox]
end

def current_choice_number
  max_trial = ImageChoice.where(worker_id: @worker_id, stimset_id: @job).maximum(:trial)
  @current_choice_number = max_trial ? max_trial.to_i + 1 : 0
end

def clean_filename(path)
  path.to_s.sub(/^#{stimuli_folder_name}\//, '')
end

def set_variables
  @choice = params[:choice] == 'none' ? nil : params[:choice]
  @condition = params[:condition]
end

def write_to_db
  image_choice = {
    assignment_id: @assignment_id,
    image_one: clean_filename(params[:image_one]),
    image_two: clean_filename(params[:image_two]),
    image_three: clean_filename(params[:image_three]),
    chosen_image: clean_filename(@choice),
    condition: @condition,
    reaction_time: params[:reaction_time]
  }

  ImageChoice.where(trial: @n, worker_id: @worker_id, stimset_id: @job).first_or_create(image_choice)
end

MturkThumbnails.controllers do
  before do
    p params
    read_params
  end
  
  post :choose, with: :choice do
    set_variables
    write_to_db
  end

  get :experiment do
    @experiment_data = {
      'img_dir' => stimuli_folder_name,
      'cur_trial' => current_choice_number,
      'images' => get_image_list,
      'trials' => get_trial_sequence
    }.to_json;

    @job_data = {
      'assignment_id' => @assignment_id,
      'hit_id' => @hit_id,
      'worker_id' => @worker_id,
      's3_bucket' => @s3_bucket,
      'job' => @job,
      'turk_url' => get_amazon_url
    }.to_json;

    haml :experiment
  end
end
