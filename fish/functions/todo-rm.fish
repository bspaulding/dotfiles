function todo-rm --description 'Delete a "### <name>" TODO section (heading + body) from $HOME/vim_notes.md'
    if test (count $argv) -eq 0
        echo "usage: todo-rm <todo-name> [file]" >&2
        return 1
    end

    set -l name $argv[1]
    set -l file $HOME/vim_notes.md
    if test (count $argv) -ge 2
        set file $argv[2]
    end

    if not test -f $file
        echo "todo-rm: no such file: $file" >&2
        return 1
    end

    if not grep -qxF "### $name" $file
        echo "todo-rm: no section '### $name' found in $file" >&2
        return 1
    end

    set -l tmp (mktemp)
    awk -v target="$name" '
        /^## / { skip = 0 }
        /^### / {
            if ($0 == "### " target) { skip = 1; next }
            else { skip = 0 }
        }
        skip { next }
        { print }
    ' $file > $tmp

    mv $tmp $file
    echo "todo-rm: removed section '$name' from $file"
end
