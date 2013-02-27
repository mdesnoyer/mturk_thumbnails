$ ->
  nextPage = ->
    params = $('#container').data()
    param_str = 'assignment_id=' + params['assignmentId'] + '&image_one=' + params['imageOne'] + '&image_two=' + params['imageTwo'] + '&image_three=' + params['imageThree'] + '&n=' + params['n'] + '&hit_id=' + params['hitId'] + '&worker_id=' + params['workerId']
    url = $(location).attr('origin') + '/choose/none?' + param_str
    window.location.href = url
  # 
  # if $('#container').data('assignment-id') != 'ASSIGNMENT_ID_NOT_AVAILABLE'
  #   window.setTimeout(nextPage, 1500)