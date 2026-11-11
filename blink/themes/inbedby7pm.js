// In Bed by 7pm — Blink Shell theme
//
// Ported from Sarah Drasner's VS Code theme (sdras/inbedby7pm)
// https://github.com/sdras/inbedby7pm
// Ported from ghostty/themes/inbedby7pm
//
// Install: in Blink Shell go to Settings -> Appearance -> Themes -> "+" ->
// "Import from URL", and paste the raw URL of this file, e.g.
// https://raw.githubusercontent.com/bspaulding/dotfiles/main/blink/themes/inbedby7pm.js

black        = '#1e1e3f';
red          = '#ff628c';
green        = '#3ad900';
yellow       = '#fad000';
blue         = '#4d8acf';
magenta      = '#c792ea';
cyan         = '#00daef';
white        = '#a599e9';
lightBlack   = '#4b4880';
lightRed     = '#ff628c';
lightGreen   = '#3ad900';
lightYellow  = '#fad000';
lightBlue    = '#9effff';
lightMagenta = '#ff9ac1';
lightCyan    = '#00daef';
lightWhite   = '#efe9fc';

t.prefs_.set('color-palette-overrides',
  [ black,      red,      green,      yellow,
    blue,       magenta,  cyan,       white,
    lightBlack, lightRed, lightGreen, lightYellow,
    lightBlue,  lightMagenta, lightCyan, lightWhite ]);

t.prefs_.set('foreground-color', '#a599e9');
t.prefs_.set('background-color', '#1e1e3f');
t.prefs_.set('cursor-color', 'rgba(165, 153, 233, 0.5)');
t.prefs_.set('selection-color', 'rgba(52, 43, 87, 0.6)');
