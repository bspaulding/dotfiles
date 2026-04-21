if test -d /nix/var/nix/profiles/default/bin
    fish_add_path /nix/var/nix/profiles/default/bin
end

if test -d $HOME/.nix-profile/bin
    fish_add_path $HOME/.nix-profile/bin
end
