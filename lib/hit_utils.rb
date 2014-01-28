def QuestionURL2Stimset(jobId)
  # Extract out the stimset id
  reg = /job=(?<stimset>[A-Za-z0-9_\-]+)_[A-Za-z0-9]+&/x

  parse = jobId.match(reg)
  if parse.nil? then
    stimset = jobId
  else
    stimset = parse['stimset']
  end

  return stimset
end
