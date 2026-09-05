# dotfiles

A collection of dotfiles for my dev setup.

## Installation

Clone the repo and run the install script:

```bash
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles
./install
```

The install script will:
- Create symlinks from this repo to standard config locations
- Back up any existing configurations with timestamps to `~/.dotfiles-backup-YYYYMMDD-HHMMSS/`
- Install vim configuration (clones separate [.vim repo](https://github.com/bspaulding/.vim))
- Handle all configs: alacritty, fish, tmux

## Scripts

### `./install`
Installs dotfiles by creating symlinks from the repo to your home directory.

**What it links:**
- `./nix/nix.conf` → `~/.config/nix/nix.conf`
- `./alacritty/` → `~/.config/alacritty/`
- `./fish/config.fish` → `~/.config/fish/config.fish`
- `./fish/conf.d/` → `~/.config/fish/conf.d/`
- `./fish/functions/` → `~/.config/fish/functions/`
- `./tmux/.tmux.conf` → `~/.tmux.conf`
- `./tmux/` → `~/.config/tmux/`

**Safety features:**
- Automatically backs up existing configs before linking
- Creates necessary parent directories
- Skips missing source files with warnings
- Colored output for easy tracking

### `./capture`
Captures current config files from your home directory into this repo.

**Use this when:**
- Setting up the repo on a new machine for the first time
- You've made changes to configs and want to sync them to the repo
- Adding new config files to track

```bash
./capture
git status          # Review what changed
git add .
git commit -m "Update dotfiles"
git push
```

### `./restore`
Restores configs from a backup created by the install script.

**Use this when:**
- Something goes wrong after running install
- You want to revert to previous configs
- Testing changes safely

```bash
./restore ~/.dotfiles-backup-20260214-143945
```

The script will show available backups if you don't specify one.

## Workflow

**Initial Setup (New Machine):**
1. Clone this repo
2. Run `./install`
3. Your configs are now symlinked and ready

**Updating Configs:**
1. Edit files in this repo (changes apply immediately via symlinks)
2. Commit and push changes
3. Pull on other machines

**Capturing New Configs:**
1. Make changes to your actual config files
2. Run `./capture` to sync them to repo
3. Review, commit, and push

**Recovery:**
If something breaks: `./restore <backup-dir>`

