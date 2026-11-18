#!/usr/bin/env bash
# tmux-save.sh — serialize tmux state to JSON on stdout.  Called by the tmux-save fish function.
#
# It does the whole job in a fixed number of external calls regardless of how many
# sessions there are (an earlier per-pane implementation took ~13s at 47 sessions):
#   tmux x1, ps x1, lsof x1 and ls x1 (only if a pi is running),
#   jq x1 for claude PID.json files (only if needed), jq x1 to assemble.
#
# Agent session ids:
#   claude  the --resume argument, else ~/.claude/sessions/<pid>.json
#   pi      keeps no session file open and exposes no argv/env for its session, so match
#           by start time: a fresh (or /new'd) pi owns the newest session file created
#           during its lifetime [its start, next peer's start); otherwise it resumed an
#           older session -> the newest-mtime file created before any live pi in that
#           cwd started.  2s slack: lstart is whole seconds, the file appears ~0.5s later.
#           Known limit: two peers that both *resumed* old sessions collide.
#
# Portability: written for bash 3.2 (macOS /bin/bash: no associative arrays) and for
# BWK awk (macOS awk: no newlines in `awk -v`).  Needs jq >= 1.6.
shopt -s nullglob
SEP='|'
panes=$(tmux list-panes -a -F "#{session_name}${SEP}#{window_index}${SEP}#{window_name}${SEP}#{pane_index}${SEP}#{pane_pid}${SEP}#{pane_current_command}${SEP}#{pane_current_path}" 2>/dev/null)
[ -z "$panes" ] && { echo '[]'; exit 0; }

# 1. ONE process snapshot.  Fields: ppid pid lstart(5 words) comm args...
#    P<TAB>pid<TAB>lstart            every live pi (needed as peers, even outside tmux)
#    A<TAB>ppid<TAB>pid<TAB>kind<TAB>resume-id   first agent per pane pid (mirrors awk '...; exit')
snap=$(ps -eo ppid=,pid=,lstart=,comm=,args= | awk -v panes="$(cut -d'|' -f5 <<<"$panes" | paste -sd, -)" '
  BEGIN { n = split(panes, a, ","); for (i = 1; i <= n; i++) isPane[a[i]] = 1 }
  $8 == "claude" || $8 == "pi" {
    if ($8 == "pi") printf "P\t%s\t%s %s %s %s %s\n", $2, $3, $4, $5, $6, $7
    if (($1 in isPane) && !($1 in seen)) {
      seen[$1] = 1; sid = ""
      if ($8 == "claude") { s = $0; while (match(s, /--resume [a-f0-9-]*/)) { sid = substr(s, RSTART + 9, RLENGTH - 9); s = substr(s, RSTART + RLENGTH) } }
      printf "A\t%s\t%s\t%s\t%s\n", $1, $2, $8, sid
    }
  }')

# 2. claude agents lacking --resume: batch-read PID.json (skip missing: jq aborts a batch at the 2nd unreadable file)
claude_files=()
while IFS=$'\t' read -r _ _ pid kind sid; do
  [ "$kind" = claude ] && [ -z "$sid" ] && [ -f "$HOME/.claude/sessions/$pid.json" ] && claude_files+=("$HOME/.claude/sessions/$pid.json")
done < <(grep '^A' <<<"$snap")
pidjson=""
[ ${#claude_files[@]} -gt 0 ] && pidjson=$(jq -r '[input_filename, (.sessionId // "")] | @tsv' "${claude_files[@]}" 2>/dev/null)

# 3. pi: cwd of every live pi in ONE lsof; newest-first session files for those cwds in ONE ls -t
cwds=""; files=""
pi_pids=$(awk -F'\t' '$1=="P"{printf "%s%s", (n++ ? "," : ""), $2}' <<<"$snap")
if [ -n "$pi_pids" ]; then
  cwds=$(lsof -a -d cwd -Fpn -p "$pi_pids" 2>/dev/null | awk '/^p/{pid=substr($0,2)} /^n/{print pid "\t" substr($0,2)}')
  globs=()
  while IFS= read -r slug; do
    globs+=("$HOME/.pi/agent/sessions/--$slug--"/*.jsonl)
  done < <(cut -f2 <<<"$cwds" | sed 's|^/||; s|/|-|g' | sort -u)
  [ ${#globs[@]} -gt 0 ] && files=$(ls -t "${globs[@]}" 2>/dev/null)
fi

# 4. assemble
jq -R -s --arg snap "$snap" --arg pidjson "$pidjson" --arg cwds "$cwds" --arg files "$files" --arg home "$HOME" '
  def tsv: split("\n") | map(select(length > 0) | split("\t"));
  # local-time lstart -> epoch, DST-safe: fix the UTC offset at the instant itself
  def lstart_epoch:
    (strptime("%a %b %e %T %Y") | mktime) as $w
    | (now | floor) as $n
    | ((($n | localtime | mktime) - $n)) as $off0
    | ($w - $off0) as $e0
    | (($e0 | localtime | mktime) - $e0) as $off1
    | $w - $off1;
  def file_epoch: (split("/")[-1] | capture("^(?<t>\\d{4}-\\d{2}-\\d{2}T\\d{2}-\\d{2}-\\d{2})").t?) as $t
    | if $t == null then null else ($t | strptime("%Y-%m-%dT%H-%M-%S") | mktime) end;
  def slugdir($cwd): $home + "/.pi/agent/sessions/--" + ($cwd | ltrimstr("/") | gsub("/"; "-")) + "--/";

  ($snap | tsv) as $S
  | ($pidjson | tsv | map({key: (.[0] | split("/")[-1] | rtrimstr(".json")), value: .[1]}) | from_entries) as $pj
  | ($cwds | tsv | map({key: .[0], value: .[1]}) | from_entries) as $cwd
  | ([$S[] | select(.[0] == "P") | {pid: .[1], start: (.[2] | try lstart_epoch catch null)}]) as $pis
  | ($files | split("\n") | map(select(length > 0))) as $allfiles

  | def pi_sid($pid):
      ($cwd[$pid]) as $c | ($pis | map(select(.pid == $pid)) | .[0].start) as $my
      | if $c == null or $my == null then ""
        else
          ($allfiles | map(select(startswith(slugdir($c))))) as $fs
          | if ($fs | length) == 0 then "" else
              ([$pis[] | select($cwd[.pid] == $c and .start != null) | .start] | sort) as $starts
              | (first($starts[] | select(. > $my)) // 99999999999) as $next
              | ($starts[0] // $my) as $first
              | def pick($lo; $hi): first($fs[] | select((file_epoch) as $e | $e != null and $e >= $lo and $e < $hi)) // null;
                (pick($my - 2; $next - 2) // pick(0; $first - 2)) as $ch
              | if $ch == null then "" else ($ch | capture("^.*_(?<s>[a-f0-9-]*)\\.jsonl$").s? // "") end
            end
        end;

  ([$S[] | select(.[0] == "A")
     | {key: .[1], value: {kind: .[3], pid: .[2],
          sessionId: (if .[3] == "claude" then (if .[4] != "" then .[4] else ($pj[.[2]] // "") end) else pi_sid(.[2]) end)}}]
   | from_entries) as $ag

  # consecutive grouping preserves tmux order
  | def cgroup(f): reduce .[] as $x ([]; if length > 0 and (.[-1][0] | f) == ($x | f) then .[-1] += [$x] else . + [[$x]] end);
  [ split("\n")[] | select(length > 0) | split("|")
      | {session: .[0], idx: .[1], wname: .[2], pidx: .[3], pid: .[4], cmd: .[5], cwd: .[6]} ]
  | cgroup(.session) | map({session: .[0].session,
      windows: (cgroup(.idx) | map({index: .[0].idx, name: .[0].wname, cwd: .[0].cwd,
        panes: map({index: .pidx, pid: .pid, command: .cmd})}
        + ([.[] | $ag[.pid] | select(. != null)][0] | if . == null then {} else {agent: .} end)))})' <<<"$panes"
