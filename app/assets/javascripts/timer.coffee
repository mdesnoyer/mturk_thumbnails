$ ->
  nextPage = ->
    params = $('#container').data()
    param_str = 'assignment_id=' + params['assignmentId'] + '&image_one=' + params['imageOne'] + '&image_two=' + params['imageTwo'] + '&image_three=' + params['imageThree'] + '&n=' + params['n'] + '&hit_id=' + params['hitId'] + '&worker_id=' + params['workerId'] + '&image_set=' + params['imageSet']
    url = $(location).attr('origin') + '/choose/none?' + param_str
    window.location.href = url

  if $('#container').data('assignment-id') == 'ASSIGNMENT_ID_NOT_AVAILABLE'
    $('button').hide()
    $('p.instructions_click').hide()
  else if $(location).attr('pathname').split('/')[1] != 'keep_instructions'
    window.setTimeout(nextPage, 2000)