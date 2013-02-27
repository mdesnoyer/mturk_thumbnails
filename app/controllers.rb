TRIALS_PATH  = "#{PADRINO_ROOT}/config/trials.txt"
STIMULI_PATH = "#{PADRINO_ROOT}/config/stimuli.txt"

def load_stimuli
  stimuli_str      = File.read(STIMULI_PATH)
  stimuli_lines    = stimuli_str.split("\n")
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
  @compiled_trials ||= compile_trials
  @compiled_trials[trial_number.to_i].map { |filename| "stimuli/#{filename}" }
end

def total_choices
  @compiled_trials ||= compile_trials
  @compiled_trials.count
end

def total_trials
  @total_choices*2
end

def set_variables
  @assignment_id = params[:assignmentId] || params[:assignment_id]
  @hit_id = params[:hitId] || params[:hit_id]
  @worker_id = params[:workerId] || params[:worker_id]
  @current_choice_number = (params[:n] || 1).to_i
  @next_choice_number = @current_choice_number + 1
  @first, @second, @third = images_for_trial(@current_choice_number)
  @total_choices = total_choices
  @total_trials = total_trials
end

MturkThumbnails.controllers  do
  get :keep_instructions do
    compiled_trials = compile_trials
    @all_images = compile_trials.values.flatten.uniq.map { |filename| "stimuli/#{filename}" }

    haml :keep_instructions
  end

  get :choose, with: :choice do
    set_variables

    choice = params[:choice] == 'none' ? nil : params[:choice]

    if @current_choice_number <= 3
      condition = "KEEP"
    else
      condition = "RETURN"
    end

    # ImageChoice.create(
    #   assignment_id: @assignment_id,
    #       image_one: params[:image_one],
    #       image_two: params[:image_two],
    #     image_three: params[:image_three],
    #    chosen_image: choice,
    #       condition: condition,
    #       trial: @current_choice_number
    # )

    if @current_choice_number == 145
      haml :return_instructions
    elsif @current_choice_number <= total_trials
      haml :index
    else
      redirect "https://workersandbox.mturk.com/mturk/externalSubmit?assignmentId=#{@assignment_id}&hitId=#{@hit_id}&workerId=#{@worker_id}"
    end

  end

  get :index do
    set_variables
    p @current_choice_number
    haml :index
  end
end
