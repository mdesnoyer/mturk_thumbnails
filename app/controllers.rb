prng = Random.new
# x = prng.rand(100)

def set_stimpath
  unique_workers = ImageChoice.select(:worker_id.uniq)
  if unique_workers.size < 60
    stimuli_path = "#{PADRINO_ROOT}/config/stimuli6.txt"
  elsif unique_workers.size < 120
    stimuli_path = "#{PADRINO_ROOT}/config/stimuli7.txt"
  else
    stimuli_path = "#{PADRINO_ROOT}/config/stimuli8.txt"
  end
  stimuli_path
end

def set_stimfolder
  unique_workers = ImageChoice.select(:worker_id.uniq)
  if unique_workers.size < 60
    stimuli_folder_name = 'stimuli6'
  elsif unique_workers.size < 120
    stimuli_folder_name = 'stimuli7'
  else
    stimuli_folder_name = 'stimuli8'
  end
  stimuli_folder_name
end

TRIALS_PATH  = "#{PADRINO_ROOT}/config/trials.txt"
SANDBOX = false

def load_stimuli
  stimuli_path = set_stimpath
  stimuli_str      = File.read(stimuli_path)
  stimuli_lines    = stimuli_str.split("\r")
  stimuli_mappings = stimuli_lines.map { |line| line.split("\t") }

  stimuli_mappings.each_with_object({}) do |stimuli_mapping, hash|
    hash[stimuli_mapping[0]] = stimuli_mapping[1]
  end
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

  trials.shuffle.each_with_index do |trial, i|
    n = i + 1
    compiled_trials[n] = trial.map { |t| stimuli[t] }
  end
  
  compiled_trials
end

def images_for_trial(trial_number)
  trial_number = trial_number.to_i
  @compiled_trials ||= compile_trials
  key = trial_number > total_choices ? (trial_number - total_choices) : trial_number
  @compiled_trials[key].map { |filename| add_folder(filename) }
end

def total_choices
  @compiled_trials ||= compile_trials
  @compiled_trials.count
end

def total_trials
  total_choices * 2
end

def set_stimset_id
  stimuli_folder_name = set_stimfolder
  if stimuli_folder_name == "stimuli6"
    @stimset_id = "stimset6"
  elsif stimuli_folder_name == "stimset7"
    @stimset_id = "stimset7"
  else
    @stimset_id = "stimset8"
  end
end

def read_params
  @assignment_id = params[:assignmentId] || params[:assignment_id]
  @hit_id = params[:hitId] || params[:hit_id]
  @worker_id = params[:workerId] || params[:worker_id]
  @current_choice_number = (params[:n] || 1).to_i
end

def set_variables
  @first, @second, @third = images_for_trial(@current_choice_number)
  @total_choices = total_choices
  @total_trials = total_trials
end

def clean_filename(path)
  stimuli_folder_name = set_stimfolder
  path.to_s.sub(/^#{stimuli_folder_name}\//, '')
end

def add_folder(filename)
  stimuli_folder_name = set_stimfolder
  "#{stimuli_folder_name}/#{filename}"
end

def fetch_all_images
  compiled_trials = compile_trials
  compiled_trials.values.flatten.uniq.map { |filename| add_folder(filename) }
end

def post_to_amazon
  p 'posting to amazon'

  if SANDBOX
    redirect "https://workersandbox.mturk.com/mturk/externalSubmit?assignmentId=#{@assignment_id}&hitId=#{@hit_id}&workerId=#{@worker_id}"
  else
    redirect "https://www.mturk.com/mturk/externalSubmit?assignmentId=#{@assignment_id}&hitId=#{@hit_id}&workerId=#{@worker_id}"
  end
end

def set_choice
  @choice = params[:choice] == 'none' ? nil : params[:choice]
end

def set_condition
  if @current_choice_number <= 144
    @condition = "KEEP"
  else
    @condition = "RETURN"
  end
end

def write_to_db
  image_choice = {
    assignment_id: @assignment_id,
    image_one: clean_filename(params[:image_one]),
    image_two: clean_filename(params[:image_two]),
    image_three: clean_filename(params[:image_three]),
    chosen_image: clean_filename(@choice),
    condition: @condition,
    stimset_id: @stimset_id
  }

  p ImageChoice.where(trial: @current_choice_number.to_i, worker_id: @worker_id).first_or_create(image_choice)
end

MturkThumbnails.controllers do
  before do
    read_params
  end

  get :keep_instructions do
    if @assignment_id == 'ASSIGNMENT_ID_NOT_AVAILABLE'
      @all_images = []
    else
      @all_images = fetch_all_images
    end

    haml :keep_instructions
  end

  get :choose, with: :choice do
    p "current_choice_number: #{@current_choice_number}"
    p "worker_id: #{@worker_id}"

    if @current_choice_number == 1 && ImageChoice.where(worker_id: @worker_id).any?
      previous_count = ImageChoice.where(worker_id: @worker_id).count
      # p "worker #{worker_id} restarted after #{previous_count} trials"

      ImageChoice.where(worker_id: @worker_id).delete_all
      post_to_amazon
    else
      set_choice
      set_condition
      set_stimset_id
      write_to_db

      @current_choice_number = ImageChoice.where(worker_id: @worker_id).maximum(:trial).to_i + 1

      if @current_choice_number == 145
        p 'showing return instructions'
        @all_images = fetch_all_images
        haml :return_instructions
      elsif @current_choice_number <= total_trials
        p 'showing next set of images'
        set_variables
        haml :index
      else
        post_to_amazon
      end
    end
  end

  get :index do
    set_variables
    haml :index
  end
end
