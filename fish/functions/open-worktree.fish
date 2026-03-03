function open-worktree
  set name $argv[1]
  # Sanitize branch name for directory path (replace slashes with dashes)
  set sanitized_name (string replace -a / - $name)
  set worktree_path "$HOME/src/$sanitized_name"

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
