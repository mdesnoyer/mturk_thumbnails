require 'csv'
require 'open-uri/cached'

TRIALS_PATH  = "#{PADRINO_ROOT}/config/trials_mixed.csv"
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
  # Returns a image_id->image_file map
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
  trial_lines = []
  CSV.parse(trials_str) do |line|
    trial_lines << line
  end

  return trial_lines
end

def get_trial_sequence
  trials = load_trials.map{ |trial| trial.map{ |val| val.to_i } }
  # TODO(mdesnoyer): Remove this line after testing
  #trials = trials[0..6]

  return trials.shuffle(random: Random.new(@worker_id.hash & 0xFFFF))
end

def get_amazon_url
  return (params[:turkSubmitTo] || 'https://www.mturk.com') + '/mturk/externalSubmit'
end

def get_practice_images
  # If the user has done the job in the last few days, don't send
  # practice images
  if @assignment_id != "ASSIGNMENT_ID_NOT_AVAILABLE" then
    lastTime = ImageChoice.where(worker_id: @worker_id).maximum(:updated_at)
  end
  if lastTime and ((Time.now - lastTime)/86400) < 4 then
    return []
  end

  practice_path = "/assets/practice"
  trials = []
  (0...10).each do |i|
    trials << ["%s/image%i.jpg" % [practice_path, 3*i],
               "%s/image%i.jpg" % [practice_path, 3*i + 1],
               "%s/image%i.jpg" % [practice_path, 3*i + 2]]
   end
   return trials
end

def read_params
  @s3_bucket = params[:s3_bucket]
  @job = params[:job]
  @assignment_id = params[:assignmentId] || params[:assignment_id]
  @hit_id = params[:hitId] || params[:hit_id]
  @worker_id = params[:workerId] || params[:worker_id]
  @n = (params[:n] ||  0).to_i
end

def current_choice_number
  if @assignment_id != "ASSIGNMENT_ID_NOT_AVAILABLE" then
    max_trial = ImageChoice.where(worker_id: @worker_id,
                                  stimset_id: @job).maximum(:trial)
  end
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
    reaction_time: params[:reaction_time],
    worker_id: @worker_id,
    stimset_id: @job,
    trial: @n
  }

  ImageChoice.create(image_choice)
end

def register_worker(workerId, remoteIp, xForwarded, gender, age_group)
  # Registers a worker in the database
  worker_info = {
    worker_id: workerId,
    remote_ip: remoteIp,
    x_forwarded_for: xForwarded,
    gender: gender,
    age_group: age_group
  }


  if workerId then
    WorkerInfo.where(worker_id: workerId, remote_ip: remoteIp, x_forwarded_for: xForwarded).first_or_create(worker_info)
  end
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

  post :register_worker do
    register_worker(@worker_id, request.ip,
                    request.env['HTTP_X_FORWARDED_FOR'],
                    params[:gender] == '' ? nil : params[:gender],
                    params[:age_group] == '' ? nil : params[:age_group])
  end

  get :experiment do
    cur_trial = current_choice_number
    trials = get_trial_sequence
    if cur_trial >= (2 * trials.length)
      return haml :already_completed
    end

    @experiment_data = {
      'img_dir' => stimuli_folder_name,
      'cur_trial' => cur_trial,
      'images' => get_image_list,
      'trials' => trials,
      'practice_images' => get_practice_images
    }.to_json;

    @job_data = {
      'assignment_id' => @assignment_id,
      'hit_id' => @hit_id,
      'worker_id' => @worker_id,
      's3_bucket' => @s3_bucket,
      'job' => @job,
      'turk_url' => get_amazon_url
    }.to_json;

    @turk_url = get_amazon_url

    haml :experiment
  end
end
