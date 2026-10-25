#!/bin/bash
set -euo pipefail

binary=${1:?usage: release-smoke.sh /path/to/macnotif}
binary="$(cd "$(dirname "$binary")" && pwd)/$(basename "$binary")"
process_name=$(basename "$binary")
test_home=$(mktemp -d)
new_hud_pids=""
before_pids=""
log_stream_pid=""

hud_pids() {
    local pid
    for pid in $(pgrep -x "$process_name" 2>/dev/null || true); do
        if [[ "$(ps -p "$pid" -o comm=)" == "$binary" ]]; then
            echo "$pid"
        fi
    done
}

cleanup() {
    if [[ -n "$log_stream_pid" ]]; then
        kill "$log_stream_pid" 2>/dev/null || true
        wait "$log_stream_pid" 2>/dev/null || true
    fi
    for pid in $(hud_pids); do
        case " $before_pids " in
            *" $pid "*) continue ;;
        esac
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            wait "$pid" 2>/dev/null || true
        fi
    done
    rm -rf "$test_home"
}
trap cleanup EXIT

export HOME="$test_home"
export CFFIXED_USER_HOME="$test_home"
unset XDG_CONFIG_HOME

state_dir="$test_home/Library/Application Support/MacNotif"
permanent_file="$state_dir/permanent.json"
temporary_file="$state_dir/temporary.json"
before_pids=$(hud_pids)

mkdir -p "$test_home/.config"
config_file="$test_home/.config/macnotif.toml"

expect_config_error() {
    local contents=$1 diagnostic=$2
    printf '%s\n' "$contents" > "$config_file"
    if "$binary" --title "Invalid config" --mode temporary --duration 1 \
        >"$test_home/stdout" 2>"$test_home/stderr"; then
        echo "macnotif accepted invalid config: $contents" >&2
        exit 1
    fi
    grep -Fq "$config_file:" "$test_home/stderr"
    grep -Fq "$diagnostic" "$test_home/stderr"
    test ! -e "$permanent_file"
    test ! -e "$temporary_file"
    test "$(hud_pids)" = "$before_pids"
}

expect_config_error '[notice]
unknown = true' 'unknown setting notice.unknown'
expect_config_error 'duration = 4' 'unknown setting duration'
expect_config_error '[notices]' 'unknown setting notices'
expect_config_error '[notice.extra]' 'unknown setting notice.extra'
expect_config_error '[notice]
title = "Not a default"' 'unknown setting notice.title'
expect_config_error 'notice = false' 'notice must be a table'
expect_config_error '[notice]
mode = 7' 'notice.mode must be "temporary" or "permanent"'
expect_config_error '[notice]
mode = "invalid"' 'notice.mode must be "temporary" or "permanent"'
for value in 0 -1 inf nan '"2"' true '[]' '{}'; do
    expect_config_error "[notice]
duration = $value" 'notice.duration must be a finite positive number of seconds'
done
expect_config_error 'appearance = false' 'appearance must be a table'
expect_config_error '[appearance]
accent = "#ff0000"' 'unknown setting appearance.accent'
for key in width min_height padding icon_spacing text_spacing stack_spacing title_size detail_size symbol_size corner_radius border_width animation_duration; do
    for value in -1 inf nan '"14"' true '[]' 10000; do
        expect_config_error "[appearance]
$key = $value" "appearance.$key must be a finite number"
    done
done
for key in width min_height title_size detail_size symbol_size; do
    expect_config_error "[appearance]
$key = 0" "appearance.$key must be a finite number"
done
expect_config_error '[appearance]
shadow = "false"' 'appearance.shadow must be a boolean'
for key in permanent_symbol temporary_symbol; do
    for value in '""' '"not.a.real.macnotif.symbol"' 1; do
        expect_config_error "[appearance]
$key = $value" "appearance.$key must be a valid SF Symbol name"
    done
done
for theme in light dark; do
    expect_config_error "[appearance]
$theme = false" "appearance.$theme must be a table"
    expect_config_error "[appearance.$theme]
accent = '#ff0000'" "unknown setting appearance.$theme.accent"
    for key in background title detail symbol border; do
        for value in '"ff0000"' '"#fff"' '"#gg0000"' '"#123456789"' 1; do
            expect_config_error "[appearance.$theme]
$key = $value" "appearance.$theme.$key must be"
        done
    done
done
expect_config_error '[display]
unknown = true' 'unknown setting display.unknown'
expect_config_error 'display = false' 'display must be a table'
expect_config_error '[display]
id = 0' 'display.id must be a positive 32-bit display ID'
expect_config_error '[display]
id = 4294967296' 'display.id must be a positive 32-bit display ID'
expect_config_error '[layout]
anchor = "center"' 'layout.anchor must be "top-left", "top-right", "bottom-left", or "bottom-right"'
expect_config_error '[layout]
horizontal_inset = -1' 'layout.horizontal_inset must be a finite non-negative number of points'
expect_config_error '[layout]
vertical_inset = true' 'layout.vertical_inset must be a finite non-negative number of points'
expect_config_error '[notice
mode = "permanent"' ':1:'
expect_config_error '[notice]
mode = "temporary"
mode = "permanent"' ':3:'

# An unavailable configured display keeps the running HUD available and warns
# through macOS unified logging.
printf '[display]\nid = 4000000000\n' > "$config_file"
log stream --style compact --level warning \
    --predicate 'subsystem == "com.mohrworks.macnotif" AND eventMessage CONTAINS "Configured display"' \
    >"$test_home/unified-log" 2>&1 &
log_stream_pid=$!
sleep 0.5
"$binary" --title "Unavailable display fallback" --duration 30
for attempt in {1..50}; do
    if grep -Fq 'Configured display 4000000000 is unavailable; using the main display' "$test_home/unified-log"; then
        break
    fi
    sleep 0.1
done
if ! grep -Fq 'Configured display 4000000000 is unavailable; using the main display' "$test_home/unified-log"; then
    echo "macnotif did not warn when the configured display was unavailable" >&2
    exit 1
fi
kill "$log_stream_pid"
wait "$log_stream_pid" 2>/dev/null || true
log_stream_pid=""
for pid in $(hud_pids); do
    case " $before_pids " in
        *" $pid "*) continue ;;
    esac
    kill "$pid"
    wait "$pid" 2>/dev/null || true
done
rm -rf "$state_dir"

printf '[notice]\nmode = "temporary"\nmode = "permanent"\n' > "$config_file"
if "$binary" --clear >"$test_home/stdout" 2>"$test_home/stderr"; then
    echo "macnotif --clear ignored invalid startup configuration" >&2
    exit 1
fi
grep -Fq "$config_file:" "$test_home/stderr"

# No-argument HUD startup must also fail rather than continue running.
"$binary" >"$test_home/stdout" 2>"$test_home/stderr" &
startup_pid=$!
for attempt in {1..20}; do
    if ! kill -0 "$startup_pid" 2>/dev/null; then
        break
    fi
    sleep 0.1
done
if kill -0 "$startup_pid" 2>/dev/null; then
    kill "$startup_pid"
    wait "$startup_pid" 2>/dev/null || true
    echo "HUD kept running with invalid startup configuration" >&2
    exit 1
fi
if wait "$startup_pid"; then
    echo "HUD accepted invalid startup configuration" >&2
    exit 1
fi
grep -Fq "$config_file:3:" "$test_home/stderr"
test ! -e "$state_dir"

# Files that exist but cannot be read as UTF-8 TOML are not missing config.
printf '\377' > "$config_file"
if "$binary" --clear 2>"$test_home/stderr"; then
    echo "macnotif ignored invalid UTF-8 configuration" >&2
    exit 1
fi
grep -Fq "$config_file:" "$test_home/stderr"
rm "$config_file"
mkdir "$config_file"
if "$binary" --clear 2>"$test_home/stderr"; then
    echo "macnotif ignored a config path that is a directory" >&2
    exit 1
fi
grep -Fq "$config_file:" "$test_home/stderr"
rmdir "$config_file"

# Visual design is configured in TOML, independently of Notice content/lifecycle.
cat > "$config_file" <<'TOML'
[appearance]
corner_radius = 12
shadow = false
title_size = 48
detail_size = 32
symbol_size = 18
permanent_symbol = "pin.fill"
temporary_symbol = "bell"
animation_duration = 0.2
border_width = 1
width = 384
min_height = 40
padding = 14
icon_spacing = 10
text_spacing = 3
stack_spacing = 8
[appearance.light]
background = "#f5f5f5ee"
title = "#111111"
detail = "#333333"
symbol = "#333333"
border = "#666666"
[appearance.dark]
background = "#222222ee"
title = "#ffffff"
detail = "#dddddd"
symbol = "#dddddd"
border = "#999999"
TOML
"$binary" --title "Custom appearance" --description "Content is unchanged" --duration 30
grep -Fq '"title":"Custom appearance"' "$temporary_file"
grep -Fq '"description":"Content is unchanged"' "$temporary_file"
grep -Eq '"duration":30([,}])' "$temporary_file"
test ! -e "$permanent_file"
# Observe the public Window Server boundary, not private AppKit views.
appearance_pids=""
for pid in $(hud_pids); do
    case " $before_pids " in
        *" $pid "*) continue ;;
    esac
    appearance_pids="$appearance_pids $pid"
done
swift - $appearance_pids <<'SWIFT'
import CoreGraphics
import Foundation

let pids = Set(CommandLine.arguments.dropFirst().compactMap(Int32.init))
var found = false
for _ in 0..<30 {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], 0)
        as? [[String: Any]] ?? []
    for window in windows {
        guard let pid = window[kCGWindowOwnerPID as String] as? Int32,
              pids.contains(pid),
              let bounds = window[kCGWindowBounds as String] as? [String: Any],
              let width = bounds["Width"] as? Double,
              let height = bounds["Height"] as? Double else { continue }
        if width == 384 && height >= 108 { found = true; break }
    }
    if found { break }
    Thread.sleep(forTimeInterval: 0.05)
}
guard found else {
    fputs("Configured width and space for larger text were not visible at the Window Server boundary\n", stderr)
    exit(1)
}
SWIFT
rm "$config_file"

# Missing HOME config, empty files, and empty tables all keep built-in defaults.
for contents in missing '' '[notice]' '[appearance]' '[appearance.light]' '[appearance.dark]'; do
    if [[ "$contents" != missing ]]; then
        printf '%s\n' "$contents" > "$config_file"
    fi
    "$binary" --title "Default Temporary notice"
    grep -Fq '"title":"Default Temporary notice"' "$temporary_file"
    grep -Eq '"duration":1([,}])' "$temporary_file"
    test ! -e "$permanent_file"
    if [[ "$contents" == missing ]]; then
        test ! -e "$config_file"
    else
        rm "$config_file"
    fi
done

cat > "$config_file" <<'EOF'
[display]
id = 4000000000

[layout]
anchor = "bottom-left"
horizontal_inset = 24
vertical_inset = 32
EOF
"$binary" --title "Configured placement"
grep -Fq '"title":"Configured placement"' "$temporary_file"
grep -Eq '"duration":1([,}])' "$temporary_file"
rm "$config_file"

printf '[notice]\nmode = "permanent"\n' > "$test_home/.config/macnotif.toml"
"$binary" --title "Persistent notice"
test -f "$permanent_file"
grep -Fq '"title":"Persistent notice"' "$permanent_file"
rm "$test_home/.config/macnotif.toml"

# A mode-only config inherits the one-second duration when CLI selects Temporary.
printf "[notice]\nmode = 'permanent'\n" > "$config_file"
"$binary" --title "Mode-only defaults" --mode temporary
grep -Fq '"title":"Mode-only defaults"' "$temporary_file"
grep -Eq '"duration":1([,}])' "$temporary_file"
rm "$config_file"

sleep 1
after_pids=$(hud_pids)
for pid in $after_pids; do
    case " $before_pids " in
        *" $pid "*) ;;
        *) new_hud_pids="$new_hud_pids $pid" ;;
    esac
done
if [[ "$(echo "$new_hud_pids" | wc -w | tr -d ' ')" != 1 ]]; then
    echo "macnotif must launch exactly one HUD executable" >&2
    exit 1
fi

# A partial duration config keeps Temporary notice mode. XDG takes precedence
# over a conflicting HOME config, and explicit CLI values override both fields.
export XDG_CONFIG_HOME="$test_home/xdg"
mkdir -p "$XDG_CONFIG_HOME"
printf '[notice]\nmode = "permanent"\n' > "$test_home/.config/macnotif.toml"
printf '[notice]\nduration = 2.5\n' > "$XDG_CONFIG_HOME/macnotif.toml"
"$binary" --title "Configured temporary"
grep -Fq '"title":"Configured temporary"' "$temporary_file"
grep -Fq '"duration":2.5' "$temporary_file"
"$binary" --title "Explicit duration" --duration 4
grep -Fq '"duration":4' "$temporary_file"
printf '[notice]\nmode = "permanent"\nduration = 30\n' > "$XDG_CONFIG_HOME/macnotif.toml"
"$binary" --title "Explicit temporary" --mode temporary --duration 5
grep -Fq '"title":"Explicit temporary"' "$temporary_file"
grep -Fq '"duration":5' "$temporary_file"
"$binary" --title "Configured permanent"
grep -Fq '"title":"Configured permanent"' "$permanent_file"
if grep -Fq '"duration"' "$permanent_file"; then
    echo "Permanent notice unexpectedly has a duration" >&2
    exit 1
fi
rm "$XDG_CONFIG_HOME/macnotif.toml"
"$binary" --title "Built-in defaults"
grep -Fq '"title":"Built-in defaults"' "$temporary_file"
grep -Fq '"duration":1' "$temporary_file"
test ! -e "$XDG_CONFIG_HOME/macnotif.toml"
# Valid TOML dotted keys, quoted keys, numeric syntax, and comments are accepted.
printf '"notice".duration = 0x2 # seconds\n' > "$XDG_CONFIG_HOME/macnotif.toml"
"$binary" --title "TOML syntax"
grep -Fq '"title":"TOML syntax"' "$temporary_file"
grep -Eq '"duration":2([,}])' "$temporary_file"
rm "$XDG_CONFIG_HOME/macnotif.toml"
rm "$test_home/.config/macnotif.toml"
unset XDG_CONFIG_HOME

"$binary" --title "Temporary notice" --duration 30
test -f "$temporary_file"
grep -Fq '"title":"Temporary notice"' "$temporary_file"
grep -Fq '"title":"Configured permanent"' "$permanent_file"

"$binary" --title "Updated release smoke test" --mode permanent
grep -Fq '"title":"Updated release smoke test"' "$permanent_file"
grep -Fq '"title":"Temporary notice"' "$temporary_file"
sleep 1
after_pids=$(hud_pids)
for pid in $after_pids; do
    case " $before_pids " in
        *" $pid "*) ;;
        *)
            case " $new_hud_pids " in
                *" $pid "*) ;;
                *)
                    new_hud_pids="$new_hud_pids $pid"
                    echo "Repeated CLI invocation launched another HUD process" >&2
                    exit 1
                    ;;
            esac
            ;;
    esac
done

"$binary" --clear
test ! -e "$permanent_file"
test -f "$temporary_file"

for args in "--border-color" "--title Removed --border-color ff0000"; do
    if "$binary" $args >"$test_home/stdout" 2>"$test_home/stderr"; then
        echo "macnotif accepted the removed --border-color option" >&2
        exit 1
    fi
    grep -Fq 'unsupported option --border-color' "$test_home/stderr"
done

if "$binary" mode resize 2>/dev/null; then
    echo "macnotif accepted the removed mode subcommand" >&2
    exit 1
fi
if "$binary" end 2>/dev/null; then
    echo "macnotif accepted the removed end subcommand" >&2
    exit 1
fi
if "$binary" --title "Invalid duration" --duration 0 2>/dev/null; then
    echo "macnotif accepted a non-positive duration" >&2
    exit 1
fi
for value in -1 inf nan; do
    if "$binary" --title "Invalid duration" --duration "$value" 2>"$test_home/stderr"; then
        echo "macnotif accepted invalid CLI duration: $value" >&2
        exit 1
    fi
    grep -Fq 'duration must be a positive number of seconds' "$test_home/stderr"
done
if "$binary" --title "Invalid mode" --mode invalid 2>"$test_home/stderr"; then
    echo "macnotif accepted an invalid CLI mode" >&2
    exit 1
fi
grep -Fq 'mode must be temporary or permanent' "$test_home/stderr"

for pid in $new_hud_pids; do
    kill "$pid"
    wait "$pid" 2>/dev/null || true
done
new_hud_pids=""

(
    "$binary" >/dev/null 2>&1 &
    hud_pid=$!
    sleep 1
    if ! kill -0 "$hud_pid" 2>/dev/null; then
        echo "macnotif exited instead of keeping the HUD running" >&2
        exit 1
    fi
    kill "$hud_pid"
    wait "$hud_pid" 2>/dev/null || true
) 2>/dev/null

echo "Release smoke test passed"
