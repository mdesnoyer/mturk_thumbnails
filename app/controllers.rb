require 'csv'
require 'open-uri-cached'

TRIALS_PATH  = "#{PADRINO_ROOT}/config/trials.txt"
SANDBOX = false
TRIAL_COUNT = 144
RETURN_INSTRUCTIONS_START = TRIAL_COUNT + 1
TOTAL_TRIALS = TRIAL_COUNT * 2

def image_set_path
  "https://s3.amazonaws.com/#{@s3_bucket}/#{@job}_stimuli.csv"
end

def stimuli_folder_name
  "https://s3.amazonaws.com/#{@s3_bucket}"
end

def load_stimuli
  retval = Hash.new
  CSV.foreach(image_set_path) do |row|
    retval[row[0]] = row[1]
  end

  return retval
end

def load_trials
  trials_str = File.read(TRIALS_PATH)
  trial_lines = trials_str.split("\r")
  trial_lines[1..-1].map { |line| line.split("\t") }
end

def compile_trials
  trials = load_trials
  stimuli = load_stimuli
  compiled_trials = {}

  trials.shuffle(random: Random.new(1)).each_with_index do |trial, i|
    n = i + 1
    compiled_trials[n] = trial.map { |t| stimuli[t] }
  end

  ####################
  # puts compiled_trials
  ####################

  compiled_trials
end

def images_for_trial(trial_number)
  trial_number = trial_number.to_i
  @compiled_trials ||= compile_trials
  key = trial_number > TRIAL_COUNT ? (trial_number - TRIAL_COUNT) : trial_number
  @compiled_trials[key].map { |filename| add_folder(filename) }
end

def read_params
  @s3_bucket = params[:s3_bucket]
  @job = params[:job]
  @assignment_id = params[:assignmentId] || params[:assignment_id]
  @hit_id = params[:hitId] || params[:hit_id]
  @worker_id = params[:workerId] || params[:worker_id]
  @n = (params[:n] ||  1).to_i
end

def set_images
  p "current_choice_number: #{current_choice_number}"
  @first, @second, @third = images_for_trial(current_choice_number)
end

def current_choice_number
  max_trial = ImageChoice.where(worker_id: @worker_id, stimset_id: @image_set).maximum(:trial)
  @current_choice_number = max_trial ? max_trial.to_i + 1 : 1
end

def clean_filename(path)
  escape_folder = Regexp.escape(stimuli_folder_name)
  path.to_s.sub(/^#{escape_folder}\//, '')
end

def add_folder(filename)
  "#{stimuli_folder_name}/#{filename}"
end

def fetch_all_images
  compiled_trials = compile_trials
  compiled_trials.values.flatten.uniq.map { |filename| add_folder(filename) }
end

def post_to_amazon
  if SANDBOX
    redirect "https://workersandbox.mturk.com/mturk/externalSubmit?assignmentId=#{@assignment_id}&hitId=#{@hit_id}&workerId=#{@worker_id}"
  else
    redirect "https://www.mturk.com/mturk/externalSubmit?assignmentId=#{@assignment_id}&hitId=#{@hit_id}&workerId=#{@worker_id}"
  end
end

def set_variables
  @choice = params[:choice] == 'none' ? nil : params[:choice]
  @condition = current_choice_number <= TRIAL_COUNT ? 'KEEP' : 'RETURN'
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

  ImageChoice.where(trial: @n, worker_id: @worker_id, stimset_id: @image_set).first_or_create(image_choice)
end

def worker_already_completed?
  ImageChoice.where(worker_id: @worker_id, stimset_id: @image_set).any?
end

MturkThumbnails.controllers do
  before do
    p params
    read_params
  end

  get 'keep_instructions/:s3_bucket' do
    if @assignment_id == 'ASSIGNMENT_ID_NOT_AVAILABLE'
      if worker_already_completed?
        haml :already_completed
      else
        haml :keep_instructions
      end
    else
      @s3_bucket  = params[:s3_bucket]
      @all_images = fetch_all_images

      haml :keep_instructions
    end
  end

  get :choose, with: :choice do
    set_variables
    write_to_db

    if current_choice_number == RETURN_INSTRUCTIONS_START
      haml :return_instructions
    elsif current_choice_number <= TOTAL_TRIALS
      set_images

      haml :index
    else
      post_to_amazon
    end
  end

  get :index do
    set_images

    haml :index
  end
end
