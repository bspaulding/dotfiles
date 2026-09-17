function gitworkdel --description 'Force-remove git worktrees matching a needle (git worktree list | grep <needle> | cut -d\' \' -f1 | xargs git worktree remove -f)'
  git worktree list | grep $argv | cut -d' ' -f1 | xargs -I{} git worktree remove -f {}
end
