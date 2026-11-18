# tmux-save [output_path]
#   Serialize tmux state (sessions, windows, panes, claude/pi agent session ids) to JSON.
#   Default output: ~/.tmux-save.json
#   The work is done by tmux-save.sh, which lives next to this file.
#   The output is written atomically (temp file in the same directory, then rename),
#   and an existing file is left untouched if anything fails.
function tmux-save --description 'Dump tmux sessions/windows/panes/agent-ids to JSON'
    set -l output_path $argv[1]
    if test -z "$output_path"
        set output_path ~/.tmux-save.json
    end

    set -l script (path dirname (status filename))/tmux-save.sh
    if not test -f "$script"
        echo "tmux-save: missing $script" >&2
        return 1
    end

    set -l tmpfile (mktemp "$output_path.XXXXXX")
    if test $status -ne 0
        echo "tmux-save: failed to create temp file next to $output_path" >&2
        return 1
    end

    bash "$script" > $tmpfile
    set -l run_status $status
    if test $run_status -ne 0; or not jq -e 'type == "array"' $tmpfile >/dev/null 2>&1
        rm -f $tmpfile
        echo "tmux-save: failed to produce valid JSON" >&2
        return 1
    end

    mv -f $tmpfile "$output_path"
    echo "tmux-save: wrote $output_path"
end
