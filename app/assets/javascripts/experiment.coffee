$ ->
  edata = $('#e_images').data().edata
  jdata = $('#jobdata').data().jdata

  if jdata.assignment_id == "ASSIGNMENT_ID_NOT_AVAILABLE"
    $('#start_box').css("visibility", "hidden")

  curTrial = edata.cur_trial
  DisplayInstructions = ->
    $('#experiment').css("visibility", "hidden")
    $('#loading').css("visibility", "hidden")
    $('#donejob').css("visibility", "hidden")
    $('#donepractice').css("visibility", "hidden")
    if curTrial < edata.trials.length
       $('#keep_instructions').css("visibility", "visible")
    else
       $('#return_instructions').css("visibility", "visible")
  DisplayInstructions()

  ### Sends a choice back to the server ###
  trialsRegistered = edata.cur_trial
  RegisterChoice = (idx) ->
    window.clearTimeout(timeoutId)
    endTime = new Date()
    reactionTime = endTime - startTime

    # If we're practicing don't record anything
    if practice_trial <= edata.practice_images.length
      DrawVisualWash(DisplayNextPracticeTrial)
      return

    trialSeq = edata.trials[curTrial % edata.trials.length]
    postParams =
      assignment_id: jdata.assignment_id
      hit_id: jdata.hit_id
      worker_id: jdata.worker_id
      s3_bucket: jdata.s3_bucket
      job: jdata.job
      image_one: edata.images[trialSeq[0]]
      image_two: edata.images[trialSeq[1]]
      image_three: edata.images[trialSeq[2]]
      n: curTrial
      condition: if curTrial < edata.trials.length then 'KEEP' else 'RETURN'

    if idx < 0
       choice = 'none'
    else
       choice = edata.images[trialSeq[idx]]
       postParams.reaction_time = reactionTime
    
    jQuery.post('choose/' + choice,
                postParams,
                 -> trialsRegistered++)

    if (curTrial + 1) == edata.trials.length
      # Start the second phase of the experiment
      curTrial = curTrial + 1
      DisplayInstructions()
    else if (curTrial + 1) >= 2 * edata.trials.length
      FinishJob()
    else
      DrawVisualWash(() -> DisplayTrial(curTrial + 1))
  $('#left_image').click( -> RegisterChoice(0))
  $('#mid_image').click( -> RegisterChoice(1))
  $('#right_image').click( -> RegisterChoice(2))
  RegisterChoiceNone = -> RegisterChoice(-1)

  ### Handles loading the images in the background ###
  images = new Array()
  practice_images = new Array()
  imagesLoaded = 0
  LoadImages = ->
    if jdata.assignment_id == "ASSIGNMENT_ID_NOT_AVAILABLE"
       return

    for i in [0...edata.practice_images.length]
      do (i) ->
        for j in [0...3] 
          do (j) ->
            im = new Image()
            im.src = edata.practice_images[i][j]
            practice_images[3*i + j] = im
    for i in [0..(edata.images.length-1)]
      do (i) ->
        images[i] = new Image()
        images[i].onload =  -> imagesLoaded++
        images[i].src = edata.img_dir + '/' + edata.images[i]
  window.onload = LoadImages


  ### Move the triplet of images around the scene ###
  MoveImages = () ->
    eTop = 300 * Math.random() + 50
    eLeft = (($(document).width() - 850) * Math.random() + 50)
    $('#experiment').offset(top: eTop, left: eLeft)
  MoveImages()

  ### Draws the crosshairs ###
  DrawCrosshairs = (callback) ->
    canvas = $('#crosshair_canvas')[0]
    canvas.width = canvas.height = 100
    ctx = canvas.getContext('2d')

    ctx.fillStyle = "#FFFFFF"
    ctx.arc(canvas.width / 2, canvas.height / 2, canvas.width / 2, 0,
            Math.PI*2)
    ctx.fill()

    ctx.strokeStyle = "#BB0000"
    ctx.beginPath()
    ctx.moveTo(canvas.width / 2 - 40, canvas.height / 2)
    ctx.lineTo(canvas.width / 2 + 40, canvas.height / 2)
    ctx.closePath()
    ctx.stroke()
    ctx.beginPath()
    ctx.moveTo(canvas.width / 2, canvas.height / 2 - 40)
    ctx.lineTo(canvas.width / 2, canvas.height / 2 + 40)
    ctx.closePath()
    ctx.stroke()

    MoveImages()

    # Show the crosshairs
    $('#experiment').css("visibility", "hidden")
    $('#crosshairs').css("visibility", "visible")

    $(document.body).css("background", "#C0C0C0")
    setTimeout(callback, 100)

  ### Draws white noise in the wash canvas with a crosshair in the center. ###
  DrawVisualWash = (callback) ->
    canvas = $('#visual_wash')[0]
    ctx = canvas.getContext('2d')

    ### Draw the white noise ###
    imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)
    blockWidth = 10
    pixels = imageData.data
    for y in [0...canvas.height] by blockWidth
      for x in [0...canvas.width] by blockWidth
   
          color = Math.round(Math.random()) * 255;
          ctx.fillStyle = if Math.random() > 0.5 then "#000000" else "#FFFFFF"
          ctx.fillRect(x, y, blockWidth, blockWidth)

    $('#experiment').css("visibility", "hidden")
    $(document.body).css("background", "url(" + canvas.toDataURL() + ")")

    crosshairFunc = () -> DrawCrosshairs(callback)
    setTimeout(crosshairFunc, 100)

  ### Controls what trial is shown at a given time ###
  startTime = null
  timeoutId = null
  DisplayTrial = (trialNum) ->
    if trialNum >= 2 * edata.trials.length
       FinishJob()
       return

    $('#crosshairs').css("visibility", "hidden")
    $('#experiment').css("visibility", "visible")

    trialSeq = edata.trials[trialNum % edata.trials.length]
    $('#left_image').attr('src', images[trialSeq[0]].src)
    $('#mid_image').attr('src', images[trialSeq[1]].src)
    $('#right_image').attr('src', images[trialSeq[2]].src)

    #RotateImages()

    curTrial = trialNum
    startTime = new Date()

    timeoutId = setTimeout RegisterChoiceNone, 4000

  ### As the images are loading, displays the loading percentage ###
  DisplayLoadedPercent = ->
    percent = Math.round(100.0 * imagesLoaded / edata.images.length)
    if imagesLoaded == edata.images.length
       $('#loading').css("visibility", "hidden")
       $('#keep_instructions').css("visibility", "hidden")
       $('#return_instructions').css("visibility", "hidden")
       $('#donepractice').css("visibility", "hidden")
       $('#experiment').css("visibility", "visible")
       DisplayTrial(curTrial)
       return

    $('#loading_text').text("Loading... " + percent.toString() + "%")
    $('#loading').css("visibility", "visible")
    $('#keep_instructions').css("visibility", "hidden")
    $('#donepractice').css("visibility", "hidden")
    setTimeout(DisplayLoadedPercent, 200)
  $('#keep_but').click(DisplayLoadedPercent)
  $('#return_but').click(DisplayLoadedPercent)

  ### Run the practice trials ###
  practice_trial = 0
  DisplayNextPracticeTrial = ->
    practice_trial = practice_trial + 1
    if edata.practice_images.length == 0
      DisplayLoadedPercent()
      return 

    if practice_trial > edata.practice_images.length
      $('#donepractice').css("visibility", "visible")
      $('#experiment').css("visibility", "hidden")
      $('#crosshairs').css("visibility", "hidden")
      return


    $('#crosshairs').css("visibility", "hidden")
    $('#experiment').css("visibility", "visible")
    $('#keep_instructions').css("visibility", "hidden")
    $('#return_instructions').css("visibility", "hidden")

    $('#left_image').attr('src', edata.practice_images[practice_trial-1][0])
    $('#mid_image').attr('src', edata.practice_images[practice_trial-1][1])
    $('#right_image').attr('src', edata.practice_images[practice_trial-1][2])

    #RotateImages()
    
    startTime = new Date()
    timeoutId = setTimeout RegisterChoiceNone, 4000
    
  $('#practice_but').click(->
    if $('#age_group_selector').val() == "0-17"
      alert "Sorry, you must be 18 or over to do this HIT. Please return it."
      return
    if edata.practice_images.length > 0
      jQuery.post('register_worker', $('#worker_form').serialize())
    DisplayNextPracticeTrial()
  )

  if edata.practice_images.length == 0
     $('#practice_instructions').css("visibility", "hidden")
     $('#practice_but').text("Begin Experiment")
     $('#worker_form').css("visibility", "hidden")

  ### Finishes the job ###
  FinishJob = ->
    $('#experiment').css("visibility", "hidden")
    $('#crosshairs').css("visibility", "hidden")
    $('#donejob').css("visibility", "visible")
    DisplaySentPercent()
    setTimeout(SubmitToAmazon, 60000)

  ### Submits the data to Amazon ###
  SubmitToAmazon = ->
    $('#turkform').submit()
    #url = jdata.turk_url + "?assignmentId=" + jdata.assignment_id + "&workerId=" + jdata.worker_id
    #window.location = url

  ### Displays a message to the user telling them we're uploading ###
  DisplaySentPercent =  ->
    percent = Math.round(100.0 * trialsRegistered / (edata.trials.length*2))

    $('#sending_text').text("Sending Data... " + percent.toString() + "%")
    if trialsRegistered >= (edata.trials.length*2)
       SubmitToAmazon()
       return

    setTimeout(DisplaySentPercent, 200)