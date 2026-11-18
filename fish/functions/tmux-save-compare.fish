# tmux-save-compare [--keep] [--help]
#   Run tmux-save and tmux-save-fast against the live tmux server, each writing to a
#   TEMP path (the default ~/.tmux-save.json is never touched), then compare:
#     - the data (key-sorted, so only real differences show up)
#     - the exact bytes
#     - wall-clock time of each
#   Exit status: 0 = same data, 1 = data differs, 2 = could not run.
#
#   Run it on a machine/session you care about (e.g. your Mac with real claude/pi
#   agents) before trusting tmux-save-fast.  Paste the output if it reports a diff.
#
#   Known, deliberate difference: a pi whose cwd contains a space gets a session id
#   from tmux-save-fast but an empty one from tmux-save (which truncates the cwd).
#
#   The temp directory is removed on success; kept (and its path printed) when the
#   data differs or --keep is given.  It holds slow.json, fast.json, *.err, diff.txt.

# __tmux_compare_now: wall-clock seconds with millisecond resolution when perl is
# available (macOS ships it; its `date` has no %N), else whole seconds.
function __tmux_compare_now --description 'Current epoch seconds, sub-second if possible'
    if command -q perl
        perl -MTime::HiRes=time -e 'printf "%.3f\n", time'
    else
        date +%s
    end
end

# __tmux_compare_fingerprint: one line per pane; used to detect that tmux changed
# while the comparison was running (which would make a diff spurious).
function __tmux_compare_fingerprint --description 'Fingerprint of live tmux panes'
    tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_pid} #{pane_current_command} #{pane_current_path}' 2>/dev/null | sort
end

function tmux-save-compare --description 'Compare tmux-save with tmux-save-fast on live state (temp files only)'
    argparse k/keep h/help -- $argv
    or return 2
    if set -q _flag_help
        echo "usage: tmux-save-compare [--keep]"
        echo "  Runs tmux-save and tmux-save-fast to temp files and compares data and timing."
        return 0
    end

    for dep in tmux jq
        if not command -q $dep
            echo "tmux-save-compare: $dep not found" >&2
            return 2
        end
    end
    if not functions -q tmux-save; or not functions -q tmux-save-fast
        echo "tmux-save-compare: tmux-save and tmux-save-fast must both be available" >&2
        return 2
    end
    if not tmux list-sessions >/dev/null 2>&1
        echo "tmux-save-compare: no tmux server running; nothing to compare" >&2
        return 2
    end

    set -l dir (mktemp -d -t tmux-save-compare.XXXXXX)
    or begin
        echo "tmux-save-compare: could not create temp dir" >&2
        return 2
    end

    echo "== environment"
    echo "os:    "(uname -sr)
    echo "tmux:  "(tmux -V)
    echo "fish:  "(fish --version)
    echo "bash:  "(bash --version 2>&1 | head -1)
    echo "jq:    "(jq --version 2>&1)
    echo "awk:   "(awk --version 2>&1 | head -1; or true)
    echo "tmux:  "(tmux list-sessions | count)" sessions, "(tmux list-panes -a | count)" panes"
    echo

    # Each function runs in its own fish so that the shell's own error output
    # (e.g. wildcard-expansion errors) is captured in *.err instead of leaking to the terminal.
    set -l fp (string escape -- $fish_function_path | string join ' ')
    set -l before (__tmux_compare_fingerprint | string collect)

    echo "== running tmux-save      -> $dir/slow.json"
    set -l t0 (__tmux_compare_now)
    fish -c "set fish_function_path $fp; tmux-save (string escape -- $dir/slow.json)" >$dir/slow.out 2>$dir/slow.err
    set -l slow_status $status
    set -l t1 (__tmux_compare_now)

    echo "== running tmux-save-fast -> $dir/fast.json"
    set -l t2 (__tmux_compare_now)
    fish -c "set fish_function_path $fp; tmux-save-fast (string escape -- $dir/fast.json)" >$dir/fast.out 2>$dir/fast.err
    set -l fast_status $status
    set -l t3 (__tmux_compare_now)

    set -l after (__tmux_compare_fingerprint | string collect)

    set -l slow_secs (math -s3 $t1 - $t0)
    set -l fast_secs (math -s3 $t3 - $t2)
    echo
    echo "== results"
    printf 'tmux-save       exit=%s  %ss  stderr=%s lines\n' $slow_status $slow_secs (count (cat $dir/slow.err))
    printf 'tmux-save-fast  exit=%s  %ss  stderr=%s lines\n' $fast_status $fast_secs (count (cat $dir/fast.err))
    if not string match -qr '^0(\.0+)?$' -- $fast_secs
        printf 'speedup         %sx\n' (math -s1 "$slow_secs / $fast_secs")
    end

    if test $slow_status -ne 0; or test $fast_status -ne 0
        echo "tmux-save-compare: one of the functions failed (see $dir/*.err)" >&2
        return 2
    end
    for f in slow fast
        if not jq -e 'type == "array"' $dir/$f.json >/dev/null 2>&1
            echo "tmux-save-compare: $f.json is not a valid JSON array (kept in $dir)" >&2
            return 2
        end
    end

    jq -S . $dir/slow.json >$dir/slow.norm
    jq -S . $dir/fast.json >$dir/fast.norm
    set -l agents (jq '[.[].windows[].agent | select(. != null)] | length' $dir/fast.json)
    set -l with_ids (jq '[.[].windows[].agent | select(. != null and .sessionId != "")] | length' $dir/fast.json)
    echo "agents found    $agents ($with_ids with a session id)"

    set -l same_data 0
    if diff -u $dir/slow.norm $dir/fast.norm >$dir/diff.txt
        set same_data 1
    end
    set -l same_bytes 0
    if cmp -s $dir/slow.json $dir/fast.json
        set same_bytes 1
    end

    echo
    if test $same_data -eq 1
        if test $same_bytes -eq 1
            echo "RESULT: identical (data and bytes)"
        else
            echo "RESULT: same data, different formatting/key order (see: diff $dir/slow.json $dir/fast.json)"
        end
    else
        echo "RESULT: DATA DIFFERS"
        if test "$before" != "$after"
            echo "note: tmux panes changed while this ran, so some differences may be spurious; re-run to check"
        end
        echo "--- first lines of the diff (< tmux-save, > tmux-save-fast); full diff: $dir/diff.txt"
        head -60 $dir/diff.txt
    end

    if test $same_data -eq 1; and not set -q _flag_keep
        rm -rf $dir
    else
        echo "files kept in: $dir"
    end

    test $same_data -eq 1
end
