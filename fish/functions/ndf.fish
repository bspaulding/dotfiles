function ndf --description 'nix develop, landing in fish with the flake env winning over personal PATH'
    nix develop --command bash -c 'export NIX_PINNED_PATH="$PATH"; exec fish -C "set -gx PATH (string split : \"\$NIX_PINNED_PATH\") \$PATH"' $argv
end
