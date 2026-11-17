# tmux-restore — recreate tmux sessions/windows/panes from a tmux-save JSON and
# resume the claude / pi agents that were running in them.
#
# Shape: a pure planner (JSON -> rows of tmux argv) and a thin executor, so
# `--dry-run` can show exactly what would run without touching tmux.
#
# Plan row format, fields joined by the ASCII unit separator (0x1f):
#   <session> <tmux> <subcommand> <args...>   a command to run
#   <session> #      <text>                   a note for the user (not run)
#
# v1 limits (tmux-save does not record these):
#   - extra panes are plain even splits in the window's cwd (no layout, no per-pane cwd)
#   - window names are left to automatic-rename (saved names are auto-generated)
#   - agent flags (e.g. --dangerously-skip-permissions) are not saved, so not restored
#   - the agent is attached to the first pane that is not a shell or vim

# ---------------------------------------------------------------------------
# __tmux_restore_jq_program
#   Output: the jq program that turns a save file into plan rows.
#   Args (via --argjson): claude_ids, pi_ids (session ids that have transcripts
#   on disk), only (session names to restore; [] means all).
# ---------------------------------------------------------------------------
function __tmux_restore_jq_program --description 'jq planner: save file -> plan rows'
  echo '
def shells: ["fish", "zsh", "bash", "sh"];
def known($ids; $id): any($ids[]; . == $id);
def send($s; $target; $cmd): [$s, "tmux", "send-keys", "-t", $target, $cmd, "Enter"];
def note($s; $text): [$s, "#", $text];

# agent -> {cmd, note?}; resume only when the transcript exists, else start fresh.
def agent_command($claude_ids; $pi_ids):
  if .kind == "claude" then
    if known($claude_ids; .sessionId)
    then {cmd: "claude --resume \(.sessionId)"}
    else {cmd: "claude", note: "claude session \(.sessionId) has no transcript; starting a fresh one"} end
  elif .kind == "pi" then
    if known($pi_ids; .sessionId)
    then {cmd: "pi --session \(.sessionId)"}
    else {cmd: "pi", note: "pi session \(.sessionId) has no transcript; starting a fresh one"} end
  else {note: "unknown agent kind \(.kind); not restored"} end;

# window -> index of the pane holding the agent: the first pane that is not a
# shell or vim (tmux-save records the agent per window, not per pane).
def agent_pane_index:
  . as $w
  | (([$w.panes[] | select(.command as $c | any((shells + ["vim"])[]; . == $c) | not)] | first) // $w.panes[0])
  | .index;

# pane -> rows that start whatever was running in it.
def pane_rows($s; $w; $claude_ids; $pi_ids):
  ($w | agent_pane_index) as $agent_idx
  | .index as $idx
  | .command as $cmd
  | "\($s):\($w.index).\($idx)" as $target
  | if ($w.agent != null and $idx == $agent_idx) then
      ($w.agent | agent_command($claude_ids; $pi_ids)) as $a
      | [ (if $a.note then note($s; "\($target): \($a.note)") else empty end),
          (if $a.cmd then send($s; $target; $a.cmd) else empty end) ]
    elif $cmd == "vim" then [send($s; $target; "vim .")]
    elif any(shells[]; . == $cmd) then []
    else [note($s; "\($target) was running \($cmd); not restored")]
    end;

# window -> rows: create it (first window creates the session), split extra
# panes, then start commands.  A first window saved at a non-zero index is moved.
def window_rows($s; $first; $claude_ids; $pi_ids):
  . as $w
  | "\($s):\($w.index)" as $win
  | [ (if $first then
         ([$s, "tmux", "new-session", "-d", "-s", $s, "-c", $w.cwd],
          (if $w.index != "0" then [$s, "tmux", "move-window", "-s", "\($s):0", "-t", $win] else empty end))
       else [$s, "tmux", "new-window", "-d", "-t", $win, "-c", $w.cwd] end),
      ($w.panes[1:][] | [$s, "tmux", "split-window", "-d", "-t", $win, "-c", $w.cwd]),
      ($w.panes[] | pane_rows($s; $w; $claude_ids; $pi_ids)[])
    ];

def session_rows($claude_ids; $pi_ids):
  .session as $s
  | [ .windows | to_entries[] | .key as $i | .value | window_rows($s; $i == 0; $claude_ids; $pi_ids)[] ];

[ .[]
  | .session as $n
  | select(($only | length) == 0 or any($only[]; . == $n))
  | session_rows($claude_ids; $pi_ids)[] ]
| .[]
| join("\u001f")
'
end

# ---------------------------------------------------------------------------
# __tmux_restore_json_list <items...>   Output: a JSON array of strings.
# ---------------------------------------------------------------------------
function __tmux_restore_json_list --description 'Args -> JSON array of strings'
  if test (count $argv) -eq 0
    echo '[]'
  else
    printf '%s\n' $argv | jq -nR '[inputs]'
  end
end

# ---------------------------------------------------------------------------
# __tmux_restore_claude_ids / __tmux_restore_pi_ids
#   Output: JSON array of session ids that have a transcript on disk.
#   (find, not a glob: thousands of transcripts can exceed ARG_MAX.)
# ---------------------------------------------------------------------------
function __tmux_restore_claude_ids --description 'JSON array of claude session ids with transcripts'
  find ~/.claude/projects -maxdepth 2 -name '*.jsonl' 2>/dev/null \
    | string replace -r '.*/([^/]+)\.jsonl$' '$1' \
    | jq -nR '[inputs]'
end

function __tmux_restore_pi_ids --description 'JSON array of pi session ids with transcripts'
  # filenames look like 2026-11-16T15-54-46-538Z_<uuid>.jsonl
  find ~/.pi/agent/sessions -maxdepth 2 -name '*.jsonl' 2>/dev/null \
    | string replace -r '.*_([^_/]+)\.jsonl$' '$1' \
    | jq -nR '[inputs]'
end

# ---------------------------------------------------------------------------
# __tmux_restore_plan <save_file> <only_json>
#   Output: plan rows, one per line.  Pure: reads files, never calls tmux.
# ---------------------------------------------------------------------------
function __tmux_restore_plan --description 'Save file -> plan rows (pure)'
  jq -r \
    --argjson claude_ids (__tmux_restore_claude_ids | string collect) \
    --argjson pi_ids (__tmux_restore_pi_ids | string collect) \
    --argjson only $argv[2] \
    (__tmux_restore_jq_program | string collect) $argv[1]
end

# ---------------------------------------------------------------------------
# __tmux_restore_print <rows...>   Render a plan as readable text (dry run).
# ---------------------------------------------------------------------------
function __tmux_restore_print --description 'Render plan rows as text'
  for line in $argv
    set -l f (string split \x1f -- $line)
    if test "$f[2]" = '#'
      echo "# $f[3]"
    else
      string join ' ' -- (string escape -- $f[2..-1])
    end
  end
end

# ---------------------------------------------------------------------------
# __tmux_restore_exec <rows...>
#   Run the plan.  A session that already exists is skipped whole; a command
#   that fails abandons the rest of that session but not the others.
# ---------------------------------------------------------------------------
function __tmux_restore_exec --description 'Execute plan rows with tmux'
  set -l seen
  set -l skipped
  for line in $argv
    set -l f (string split \x1f -- $line)
    set -l session $f[1]

    # First row of a session: skip it entirely if tmux already has it.
    if not contains -- $session $seen
      set -a seen $session
      if command tmux has-session -t "=$session" 2>/dev/null
        set -a skipped $session
        echo "tmux-restore: session '$session' already exists, skipping" >&2
      end
    end
    contains -- $session $skipped; and continue

    if test "$f[2]" = '#'
      echo "tmux-restore: $f[3]" >&2
    else if not command $f[2..-1]
      set -a skipped $session
      echo "tmux-restore: '$session': command failed ("(string join ' ' -- $f[2..-1])"); abandoning this session" >&2
    end
  end

  set -l restored (count (for s in $seen; contains -- $s $skipped; or echo $s; end))
  echo "tmux-restore: restored $restored of "(count $seen)" session(s); skipped/failed: "(count $skipped)
end

# ---------------------------------------------------------------------------
# __tmux_restore_warn_missing_dirs <save_file>   Warn about cwds that are gone.
# ---------------------------------------------------------------------------
function __tmux_restore_warn_missing_dirs --description 'Warn about saved cwds that no longer exist'
  for d in (jq -r '[.[].windows[].cwd] | unique | .[]' $argv[1])
    test -d "$d"; or echo "tmux-restore: warning: cwd no longer exists: $d" >&2
  end
end

# ---------------------------------------------------------------------------
# tmux-restore [-n|--dry-run] [-f|--file PATH] [SESSION...]
#   Default file: ~/.tmux-save.json.  SESSION names limit what is restored.
# ---------------------------------------------------------------------------
function tmux-restore --description 'Recreate tmux sessions from a tmux-save JSON'
  argparse n/dry-run 'f/file=' h/help -- $argv; or return 1

  if set -q _flag_help
    echo 'usage: tmux-restore [-n|--dry-run] [-f|--file PATH] [SESSION...]'
    return 0
  end

  set -l file ~/.tmux-save.json
  set -q _flag_file; and set file $_flag_file

  if not jq -e 'type == "array"' $file >/dev/null 2>&1
    echo "tmux-restore: $file is missing or not a tmux-save JSON array" >&2
    return 1
  end

  set -l plan (__tmux_restore_plan $file (__tmux_restore_json_list $argv)); or return 1
  if test (count $plan) -eq 0
    echo "tmux-restore: nothing to restore" >&2
    return 1
  end

  __tmux_restore_warn_missing_dirs $file

  if set -q _flag_dry_run
    __tmux_restore_print $plan
  else
    __tmux_restore_exec $plan
  end
end
