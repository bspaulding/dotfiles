function gitworkfind --description 'List git worktrees matching a needle (git worktree list | grep <needle>)'
  git worktree list | grep $argv
end
