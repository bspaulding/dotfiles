# In Bed by 7pm - fish shell theme
# Ported from Sarah Drasner's VS Code theme (sdras/inbedby7pm)
#
# Installation:
#   cp inbedby7pm.fish ~/.config/fish/conf.d/inbedby7pm.fish
#   Then restart fish or: source ~/.config/fish/conf.d/inbedby7pm.fish

# Palette:
#   bg        #1e1e3f  deep indigo
#   bg_alt    #2d2b55  lighter indigo
#   fg        #a599e9  soft lavender
#   fg_dim    #7b6fc4  dimmer lavender
#   comment   #7a6897  muted purple-grey
#   red       #ff628c  errors
#   orange    #f08d49  constants
#   yellow    #fad000  warnings
#   green     #3ad900  strings
#   teal      #00daef  keywords
#   cyan      #9effff  parameters
#   blue      #4d8acf  functions
#   purple    #c792ea  types / accent
#   pink      #ff9ac1  special
#   white     #efe9fc  bright

# ── Syntax highlighting ───────────────────────────────────────

# Valid commands
set -g fish_color_command 4d8acf

# Invalid / unrecognized commands
set -g fish_color_error ff628c

# Strings (quoted)
set -g fish_color_quote 3ad900

# Redirection operators (>, >>, |)
set -g fish_color_redirection 00daef

# Separators (;, &, &&)
set -g fish_color_end a599e9

# Arguments and plain text
set -g fish_color_param 9effff

# Flags / options (--foo)
set -g fish_color_option ff9ac1

# Operators (=, !, !=)
set -g fish_color_operator a599e9

# Escape sequences (\n, \t)
set -g fish_color_escape c792ea

# Variables ($FOO)
set -g fish_color_variable c792ea

# Comments
set -g fish_color_comment 7a6897 --italics

# Search match highlight (in history pager)
set -g fish_color_search_match --background=2d2b55

# Selection highlight
set -g fish_color_selection --background=342b57

# Autosuggestions (ghost text)
set -g fish_color_autosuggestion 4b4880

# Valid file paths (underlined)
set -g fish_color_valid_path --underline

# Pager (tab completion list)
set -g fish_pager_color_prefix fad000 --bold
set -g fish_pager_color_completion a599e9
set -g fish_pager_color_description 7a6897 --italics
set -g fish_pager_color_progress 7b6fc4
set -g fish_pager_color_selected_background --background=342b57
set -g fish_pager_color_selected_completion efe9fc
set -g fish_pager_color_selected_description 7b6fc4

# ── Prompt colors ─────────────────────────────────────────────
# These are read by fish's default prompt and most themes.
# If you use a custom prompt framework (tide, starship, etc.)
# those have their own config — these will still apply to the
# built-in fallback prompt.

# Current directory
set -g fish_color_cwd c792ea
set -g fish_color_cwd_root ff628c

# User and host in prompt
set -g fish_color_user c792ea
set -g fish_color_host c792ea
set -g fish_color_host_remote c792ea

# Prompt decorators
set -g fish_color_status ff628c
set -g fish_color_cancel ff628c

