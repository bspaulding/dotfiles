if status is-interactive
    # Commands to run in interactive sessions can go here
    fish_vi_key_bindings
end

set -x PATH /opt/homebrew/opt/gnu-sed/libexec/gnubin $PATH
set -x PATH /nix/var/nix/profiles/default/bin $PATH

eval "$(/opt/homebrew/bin/brew shellenv)"

eval "$(fnm env)"

source $HOME/.local/bin/env.fish

set -q GHCUP_INSTALL_BASE_PREFIX[1]; or set GHCUP_INSTALL_BASE_PREFIX $HOME ; set -gx PATH $HOME/.cabal/bin $PATH /Users/bspaulding/.ghcup/bin # ghcup-env
# Added by LM Studio CLI (lms)
set -gx PATH $PATH /Users/bspaulding/.lmstudio/bin
# End of LM Studio CLI section


# opencode
fish_add_path /Users/bspaulding/.opencode/bin
