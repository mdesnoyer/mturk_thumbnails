$ ->
	window.startTime = new Date()
	params = $('#container').data()
	window.param_str = 'assignment_id=' + params['assignmentId'] + '&image_one=' + params['imageOne'] + '&image_two=' + params['imageTwo'] + '&image_three=' + params['imageThree'] + '&n=' + params['n'] + '&hit_id=' + params['hitId'] + '&worker_id=' + params['workerId'] + '&job=' + params['job'] + '&s3_bucket=' + params['s3bucket']

	nextPage = ->
		url = $(location).attr('origin') + '/choose/none?' + window.param_str
		window.location.href = url

	if $('#container').data('assignment-id') == 'ASSIGNMENT_ID_NOT_AVAILABLE'
		$('button').hide()
		$('p.instructions_click').hide()
	else if $(location).attr('pathname').split('/')[1] != 'keep_instructions'
		window.setTimeout(nextPage, 2000)
		$('a').click (event) ->
			event.preventDefault()
			endTime = new Date()
			timeSpent = (endTime - window.startTime)
			url = $(this).attr('href') + '?' + window.param_str + '&reaction_time=' + timeSpent
			window.location = url
