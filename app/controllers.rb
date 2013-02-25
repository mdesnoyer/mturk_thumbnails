def imgs
  img_paths = Dir['app/assets/images/*.*'].shuffle
  img_paths.sample(3).map { |image| File.basename(image) }
end

def total_choices
  # count how many image sets
  5
end

def set_variables
  @assignment_id = params[:assignmentId] || params[:assignment_id]
  @hit_id = params[:hitId] || params[:hit_id]
  @worker_id = params[:workerId] || params[:worker_id]
  @first, @second, @third = imgs
  @total_choices = total_choices
  @current_choice_number = (params[:n] || 1).to_i
  @next_choice_number = @current_choice_number + 1
end

MturkThumbnails.controllers  do
  get :choose, with: :choice do
    set_variables
    choice = params[:choice] == 'none' ? nil : params[:choice]

    ImageChoice.create(
      assignment_id: @assignment_id,
          image_one: params[:image_one],
          image_two: params[:image_two],
        image_three: params[:image_three],
       chosen_image: choice
    )

    if @current_choice_number <= total_choices
      haml :index
    else
      redirect "https://workersandbox.mturk.com/mturk/externalSubmit?assignmentId=#{@assignment_id}&hitId=#{@hit_id}&workerId=#{@worker_id}"
    end
  end

  get :index do
    set_variables
    haml :index
  end
end
