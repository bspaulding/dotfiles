function open-worktree
  set arg $argv[1]
  set git_common_dir (git rev-parse --git-common-dir 2>/dev/null)

  if string match -q '/*' -- $arg
    # Absolute path: use it as-is, derive the branch name from its basename
    set worktree_path $arg
    set name (path basename $arg)
  else if test -n "$git_common_dir"
    # Bare name inside a repo: put the worktree in .worktrees, a sibling of .git
    set name $arg
    set repo_root (path dirname (realpath $git_common_dir))
    set worktree_path "$repo_root/.worktrees/"(string replace -a / - $name)
  else
    set name $arg
    set worktree_path "$HOME/src/"(string replace -a / - $name)
  end

  # If the worktree path already exists, just open it
  if test -d $worktree_path
    open-project $worktree_path
    return
  end

  # Check if branch already exists
  if git show-ref --verify --quiet refs/heads/$name
    # Branch exists, create worktree from existing branch
    git worktree add $worktree_path $name
  else
    # Branch doesn't exist, create worktree with new branch
    git worktree add -b $name $worktree_path
  end

  # If successful, open the project
  if test $status -eq 0
    open-project $worktree_path
  end
end
