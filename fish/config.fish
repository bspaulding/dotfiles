if status is-interactive
    fish_vi_key_bindings
end

if test -x /opt/homebrew/bin/brew
    eval "$(/opt/homebrew/bin/brew shellenv)"
    fish_add_path /opt/homebrew/opt/gnu-sed/libexec/gnubin
end

if test -d $HOME/.local/bin
    fish_add_path $HOME/.local/bin
end

if test -f $HOME/.local/bin/env.fish
    source $HOME/.local/bin/env.fish
end

# ghcup
set -q GHCUP_INSTALL_BASE_PREFIX[1]; or set GHCUP_INSTALL_BASE_PREFIX $HOME
fish_add_path $HOME/.cabal/bin $HOME/.ghcup/bin

# LM Studio
fish_add_path $HOME/.lmstudio/bin

# opencode
fish_add_path $HOME/.opencode/bin
