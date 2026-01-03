function open-project
  set -l wd $argv[1]
  set -l session_name (string replace -a "." "_" (basename $wd))
  tmux new -s $session_name -c $wd -d
  tmux send-keys -t $session_name vim Space . Enter
  tmux new-window -t $session_name -c $wd
  tmux switchc -t $session_name
end
