$ ->
  edata = $('#experiment').data().edata
  jdata = $('#jobdata').data().jdata

  if jdata.assignment_id == "ASSIGNMENT_ID_NOT_AVAILABLE"
    $('#start_box').hide()

  curTrial = edata.cur_trial
  DisplayInstructions = ->
    $('#experiment').hide()
    $('#loading').hide()
    $('#donejob').hide()
    $('#donepractice').hide()
    if curTrial < edata.trials.length
       $('#keep_instructions').show()
    else
       $('#return_instructions').show()
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

  ### Rotates the images randomly around a central point ###
  RotateImages = () ->
    centerPos = $('#eye_center').offset()

    angleOffset = Math.PI / 3.0 * (2 * Math.random() - 1)
    angleSplit = Math.PI * 2.0 / 3.0

    mid = $('#mid_image')
    arcLen = 0.75 * Math.sqrt(Math.pow(mid.height(), 2) + 
                              Math.pow(mid.width(), 2))
    midTop = centerPos.top - arcLen * Math.cos(angleOffset) - mid.height() / 2
    midLeft = centerPos.left - arcLen * Math.sin(angleOffset) - mid.width() / 2
    mid.offset(top: midTop, left: midLeft)

    leftI = $('#left_image')
    leftTop = centerPos.top - arcLen * Math.cos(angleOffset + angleSplit) -
              leftI.height() / 2
    leftLeft = centerPos.left - arcLen * Math.sin(angleOffset + angleSplit) -
               leftI.width() / 2
    leftI.offset(top: leftTop, left: leftLeft)

    rightI = $('#right_image')
    rightTop = centerPos.top - arcLen * Math.cos(angleOffset-angleSplit) -
               rightI.height() / 2
    rightLeft = centerPos.left - arcLen * Math.sin(angleOffset-angleSplit) -
                rightI.width() / 2
    rightI.offset(top: rightTop, left: rightLeft)
    1

  ### Draws the crosshairs ###
  DrawCrosshairs = (callback) ->
    canvas = $('#crosshairs')[0]
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

    
    $('#wash_div').show()

    centerPos = $('#eye_center').offset()
    $('#crosshairs').offset(top: centerPos.top - canvas.height / 2,
                            left: centerPos.left - canvas.width / 2)

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

    $('#experiment').hide()
    $(document.body).css("background", "url(" + canvas.toDataURL() + ")")

    crosshairFunc = () -> DrawCrosshairs(callback)
    setTimeout(crosshairFunc, 50)

  ### Controls what trial is shown at a given time ###
  startTime = null
  timeoutId = null
  DisplayTrial = (trialNum) ->
    if trialNum >= 2 * edata.trials.length
       FinishJob()
       return

    $('#wash_div').hide()
    $('#experiment').show()

    trialSeq = edata.trials[trialNum % edata.trials.length]
    $('#left_image').attr('src', images[trialSeq[0]].src)
    $('#mid_image').attr('src', images[trialSeq[1]].src)
    $('#right_image').attr('src', images[trialSeq[2]].src)

    RotateImages()

    curTrial = trialNum
    startTime = new Date()

    timeoutId = setTimeout RegisterChoiceNone, 2000

  ### As the images are loading, displays the loading percentage ###
  DisplayLoadedPercent = ->
    percent = Math.round(100.0 * imagesLoaded / edata.images.length)
    if imagesLoaded == edata.images.length
       $('#loading').css("display", "none")
       $('#keep_instructions').hide()
       $('#return_instructions').hide()
       $('#donepractice').hide()
       $('#experiment').css("display", "block")
       DisplayTrial(curTrial)
       return

    $('#loading_text').text("Loading... " + percent.toString() + "%")
    $('#loading').css("display", "block")
    $('#keep_instructions').hide()
    $('#donepractice').hide()
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
      $('#wash_div').hide()
      $('#donepractice').show()
      $('#experiment').hide()
      return

    $('#wash_div').hide()
    $('#experiment').show()
    $('#keep_instructions').hide()
    $('#return_instructions').hide()

    $('#left_image').attr('src', edata.practice_images[practice_trial-1][0])
    $('#mid_image').attr('src', edata.practice_images[practice_trial-1][1])
    $('#right_image').attr('src', edata.practice_images[practice_trial-1][2])

    RotateImages()
    
    startTime = new Date()
    timeoutId = setTimeout RegisterChoiceNone, 2000
    
  $('#practice_but').click(->
    if $('#age_group_selector').val() == "0-17"
      alert "Sorry, you must be 18 or over to do this HIT. Please return it."
      return
    if edata.practice_images.length > 0
      jQuery.post('register_worker', $('#worker_form').serialize())
    DisplayNextPracticeTrial()
  )

  if edata.practice_images.length == 0
     $('#practice_instructions').hide()
     $('#practice_but').text("Begin Experiment")
     $('#worker_form').hide()

  ### Finishes the job ###
  FinishJob = ->
    $('#experiment').hide()
    $('#wash_div').hide()
    $('#donejob').show()
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