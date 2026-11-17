# tmux-save — serialize tmux state (sessions, windows, panes, agent sessions) to JSON
#
# All helper functions are defined here.  Each is independently callable for testing.

# ---------------------------------------------------------------------------
# __tmux_agent_detect <pane_pid>
#   Output: "<kind> <pid>" if a claude or pi child is found, empty otherwise.
# ---------------------------------------------------------------------------
function __tmux_agent_detect --description 'Detect claude or pi process child of a pane PID'
    set -l pane_pid $argv[1]
    if test -z "$pane_pid"
        return 1
    end
    ps -eo ppid=,pid=,comm= 2>/dev/null \
        | awk -v ppid="$pane_pid" '$1==ppid && ($3=="claude" || $3=="pi") {print $3, $2; exit}'
end

# ---------------------------------------------------------------------------
# __tmux_claude_session_id <claude_pid>
#   Output: session UUID string, or empty.
#   Fast path: --resume arg.  Fallback: ~/.claude/sessions/<PID>.json
# ---------------------------------------------------------------------------
function __tmux_claude_session_id --description 'Get claude session ID from PID'
    set -l pid $argv[1]
    if test -z "$pid"
        return 1
    end

    # Fast path: --resume <uuid> in process args
    set -l sid (ps -p $pid -o args= 2>/dev/null | sed -n 's/.*--resume \([a-f0-9-]*\).*/\1/p')
    if test -n "$sid"
        printf '%s\n' $sid
        return 0
    end

    # Fallback: PID.json
    set -l json_file ~/.claude/sessions/$pid.json
    if test -f "$json_file"
        set -l sid (jq -r '.sessionId // empty' "$json_file" 2>/dev/null)
        if test -n "$sid"
            printf '%s\n' $sid
            return 0
        end
    end

    return 1
end

# ---------------------------------------------------------------------------
# __tmux_pi_start_epoch <pid>
#   Output: process start time as epoch seconds (local-time lstart parsed).
# ---------------------------------------------------------------------------
function __tmux_pi_start_epoch --description 'Process start time as epoch seconds'
    set -l lstart (ps -p $argv[1] -o lstart= 2>/dev/null | string trim)
    test -n "$lstart"; or return 1
    date -j -f '%a %b %e %T %Y' "$lstart" +%s 2>/dev/null
end

# ---------------------------------------------------------------------------
# __tmux_pi_file_epoch <session.jsonl path>
#   Output: creation time (epoch seconds) parsed from the UTC timestamp that
#   pi puts in the filename: 2026-11-16T15-54-46-538Z_<uuid>.jsonl
# ---------------------------------------------------------------------------
function __tmux_pi_file_epoch --description 'Session creation epoch from pi session filename'
    set -l stamp (string replace -r '^(\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}).*' '$1' -- (basename $argv[1]))
    date -j -u -f '%Y-%m-%dT%H-%M-%S' "$stamp" +%s 2>/dev/null
end

# ---------------------------------------------------------------------------
# __tmux_pi_peer_starts <cwd>
#   Output: start epochs (ascending) of every live pi process whose cwd is <cwd>.
# ---------------------------------------------------------------------------
function __tmux_pi_peer_starts --description 'Start epochs of all pi processes in a cwd'
    set -l cwd $argv[1]
    for p in (ps -eo pid=,comm= | awk '$2=="pi" {print $1}')
        set -l pcwd (lsof -p $p 2>/dev/null | awk '$4=="cwd" {print $9; exit}')
        if test "$pcwd" = "$cwd"
            __tmux_pi_start_epoch $p
        end
    end | sort -n
end

# ---------------------------------------------------------------------------
# __tmux_pi_first_created_in <lo> <hi> <files...>
#   Output: first file (callers pass newest-mtime first) whose creation epoch
#   is in [lo, hi), or nothing.
# ---------------------------------------------------------------------------
function __tmux_pi_first_created_in --description 'First session file created within an epoch range'
    set -l lo $argv[1]
    set -l hi $argv[2]
    for f in $argv[3..-1]
        set -l e (__tmux_pi_file_epoch $f)
        if test -n "$e"; and test $e -ge $lo; and test $e -lt $hi
            printf '%s\n' $f
            return 0
        end
    end
    return 1
end

# ---------------------------------------------------------------------------
# __tmux_pi_session_id <pi_pid>
#   Output: session UUID string, or empty.
#
#   pi keeps no session file open and exposes no env var / argv for its session,
#   so "newest .jsonl in the cwd" is wrong whenever two pi processes share a cwd
#   (or the newest file belongs to an exited process).  Instead use start times:
#     1. A fresh pi (or one that did /new) creates its session file during its
#        own lifetime -> the newest file created in [my_start, next peer's start).
#     2. Otherwise it resumed an older session -> the newest-mtime file created
#        before any live pi in this cwd started.
#   Known limit: two peers that both *resumed* old sessions collide on rule 2.
# ---------------------------------------------------------------------------
function __tmux_pi_session_id --description 'Get pi session ID from PID'
    set -l pid $argv[1]
    test -n "$pid"; or return 1

    set -l cwd (lsof -p $pid 2>/dev/null | awk '$4=="cwd" {print $9; exit}')
    test -n "$cwd"; or return 1

    # Slug the path: strip leading /, replace / with -
    set -l slug (printf '%s' "$cwd" | sed 's|^/||; s|/|-|g')
    set -l files (command ls -t ~/.pi/agent/sessions/--$slug--/*.jsonl 2>/dev/null)
    test -n "$files"; or return 1

    set -l my_start (__tmux_pi_start_epoch $pid); or return 1
    set -l starts (__tmux_pi_peer_starts $cwd)
    # Next peer to start after me bounds my lifetime window; none -> unbounded.
    set -l next_start (printf '%s\n' $starts | awk -v s=$my_start '$1>s {print $1; exit}')
    test -n "$next_start"; or set next_start 99999999999
    set -l first_start (printf '%s\n' $starts | head -1)
    test -n "$first_start"; or set first_start $my_start

    # 2s slack: lstart is whole seconds, the file is created ~0.5s after start.
    set -l chosen (__tmux_pi_first_created_in (math $my_start - 2) (math $next_start - 2) $files)
    test -n "$chosen"; or set chosen (__tmux_pi_first_created_in 0 (math $first_start - 2) $files)
    test -n "$chosen"; or return 1

    # Extract UUID from the filename: timestamp_UUID.jsonl
    set -l sid (printf '%s' "$chosen" | sed 's/.*_\([a-f0-9-]*\)\.jsonl$/\1/')
    if test -n "$sid"; and test "$sid" != "$chosen"
        printf '%s\n' $sid
        return 0
    end
    return 1
end

# ---------------------------------------------------------------------------
# __tmux_agent_session_id <kind> <pid>
#   Output: session UUID string, or empty.
#   Dispatches to claude or pi handler.
# ---------------------------------------------------------------------------
function __tmux_agent_session_id --description 'Get agent session ID by kind and PID'
    set -l kind $argv[1]
    set -l pid $argv[2]
    if test -z "$kind" -o -z "$pid"
        return 1
    end

    switch $kind
        case claude
            __tmux_claude_session_id $pid
        case pi
            __tmux_pi_session_id $pid
        case '*'
            return 1
    end
end

# ---------------------------------------------------------------------------
# tmux-save [output_path]
#   Default output: ~/.tmux-save.json
# ---------------------------------------------------------------------------
function tmux-save --description 'Dump tmux sessions/windows/panes/agent-ids to JSON'
    set -l output_path $argv[1]
    if test -z "$output_path"
        set output_path ~/.tmux-save.json
    end

    # Collect NDJSON lines, one per session, then wrap with jq -s for the final array.
    set -l tmpfile (mktemp -t tmux-save.XXXXXX)
    if test $status -ne 0
        echo "tmux-save: failed to create temp file" >&2
        return 1
    end

    for session in (tmux list-sessions -F '#{session_name}' 2>/dev/null)
        set -l window_lines (tmux list-windows -t "$session" -F '#{window_index}|#{window_name}|#{pane_current_path}' 2>/dev/null)

        set -l window_objects
        for wline in $window_lines
            set -l parts (string split '|' -- $wline)
            set -l win_idx $parts[1]
            set -l win_name $parts[2]
            set -l win_cwd $parts[3]

            # Panes for this window
            set -l pane_lines (tmux list-panes -t "$session:$win_idx" -F '#{pane_index}|#{pane_pid}|#{pane_current_command}' 2>/dev/null)
            set -l pane_objects
            set -l pane_pids
            for pline in $pane_lines
                set -l pparts (string split '|' -- $pline)
                set -l pidx $pparts[1]
                set -l ppid $pparts[2]
                set -l pcmd $pparts[3]
                set -a pane_objects (printf '{"index":%s,"pid":%s,"command":%s}' \
                    (printf '%s' "$pidx" | jq -R -s 'rtrimstr("\n")') \
                    (printf '%s' "$ppid" | jq -R -s 'rtrimstr("\n")') \
                    (printf '%s' "$pcmd" | jq -R -s 'rtrimstr("\n")'))
                set -a pane_pids $ppid
            end

            # Agent detection: try each pane PID until we find one
            set -l agent_str ''
            for ppid in $pane_pids
                set -l agent_info (__tmux_agent_detect $ppid)
                if test -n "$agent_info"
                    set -l kind (string split ' ' -- $agent_info)[1]
                    set -l agent_pid (string split ' ' -- $agent_info)[2]
                    set -l sid (__tmux_agent_session_id $kind $agent_pid)
                    # Trim trailing newline that the helper functions emit
                    set -l sid (printf '%s' $sid)
                    set agent_str (printf ',"agent":{"kind":%s,"pid":%s,"sessionId":%s}' \
                        (printf '%s' "$kind" | jq -R -s 'rtrimstr("\n")') \
                        (printf '%s' "$agent_pid" | jq -R -s 'rtrimstr("\n")') \
                        (printf '%s' "$sid" | jq -R -s 'rtrimstr("\n")'))
                    break
                end
            end

            set -l window_obj (printf '{"index":%s,"name":%s,"cwd":%s,"panes":[%s]%s}' \
                (printf '%s' "$win_idx" | jq -R -s 'rtrimstr("\n")') \
                (printf '%s' "$win_name" | jq -R -s 'rtrimstr("\n")') \
                (printf '%s' "$win_cwd" | jq -R -s 'rtrimstr("\n")') \
                (string join ',' -- $pane_objects) \
                $agent_str)
            set -a window_objects $window_obj
        end

        # Emit one NDJSON line per session
        printf '{"session":%s,"windows":[%s]}\n' \
            (printf '%s' "$session" | jq -R -s 'rtrimstr("\n")') \
            (string join ',' -- $window_objects) \
            >> $tmpfile
    end

    # Wrap NDJSON lines into a JSON array and write to output
    jq -s '.' $tmpfile > "$output_path"
    set -l jq_status $status

    rm -f $tmpfile

    if test $jq_status -ne 0
        echo "tmux-save: jq processing failed" >&2
        return 1
    end

    echo "tmux-save: wrote $output_path"
end