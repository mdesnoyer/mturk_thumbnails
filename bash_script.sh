git commit -a -m 'Updated stimuli sets'
pid=$!
wait $pid
git push staging master
pid=$!
wait $pid
