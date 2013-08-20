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
      DisplayNextPracticeTrial()
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
      DisplayTrial(curTrial + 1)
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
        practice_images.push(new Image(edata.practice_images[i][0]))
        practice_images.push(new Image(edata.practice_images[i][1]))
        practice_images.push(new Image(edata.practice_images[i][2]))
    for i in [0..(edata.images.length-1)]
      do (i) ->
        images[i] = new Image()
        images[i].onload =  -> imagesLoaded++
        images[i].src = edata.img_dir + '/' + edata.images[i]
  window.onload = LoadImages

  ### Controls what trial is shown at a given time ###
  startTime = null
  timeoutId = null
  DisplayTrial = (trialNum) ->
    if trialNum >= 2 * edata.trials.length
       FinishJob()
       return

    trialSeq = edata.trials[trialNum % edata.trials.length]
    $('#left_image').attr('src', images[trialSeq[0]].src)
    $('#mid_image').attr('src', images[trialSeq[1]].src)
    $('#right_image').attr('src', images[trialSeq[2]].src)

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
      $('#donepractice').show()
      $('#experiment').hide()
      return

    $('#experiment').show()
    $('#keep_instructions').hide()
    $('#return_instructions').hide()

    $('#left_image').attr('src', edata.practice_images[practice_trial-1][0])
    $('#mid_image').attr('src', edata.practice_images[practice_trial-1][1])
    $('#right_image').attr('src', edata.practice_images[practice_trial-1][2])
    
    startTime = new Date()
    timeoutId = setTimeout RegisterChoiceNone, 2000
    
  $('#practice_but').click(DisplayNextPracticeTrial)

  if edata.practice_images.length == 0
     $('#practice_instructions').hide()
     $('#practice_but').text("Begin Experiment")

  ### Finishes the job ###
  FinishJob = ->
    $('#experiment').hide()
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