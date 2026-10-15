#!/bin/bash
set -euo pipefail

binary=${1:?usage: release-smoke.sh /path/to/dinky-notify}
binary="$(cd "$(dirname "$binary")" && pwd)/$(basename "$binary")"
process_name=$(basename "$binary")
test_home=$(mktemp -d)
new_hud_pids=""

cleanup() {
    for pid in $new_hud_pids; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            wait "$pid" 2>/dev/null || true
        fi
    done
    if [[ -n "${hud_pid:-}" ]] && kill -0 "$hud_pid" 2>/dev/null; then
        kill "$hud_pid"
        wait "$hud_pid" 2>/dev/null || true
    fi
    rm -rf "$test_home"
}
trap cleanup EXIT

export HOME="$test_home"
export CFFIXED_USER_HOME="$test_home"

before_pids=$(pgrep -x "$process_name" 2>/dev/null || true)
if "$binary" --title "Release smoke test" --mode permanent; then
    :
else
    echo "dinky-notify rejected a valid notice" >&2
    exit 1
fi

notice_file="$test_home/Library/Application Support/DinkyModeHUD/permanent.json"
test -f "$notice_file"
grep -Fq '"title":"Release smoke test"' "$notice_file"

sleep 1
after_pids=$(pgrep -x "$process_name" 2>/dev/null || true)
for pid in $after_pids; do
    case " $before_pids " in
        *" $pid "*) ;;
        *) new_hud_pids="$new_hud_pids $pid" ;;
    esac
done
if [[ -z "$new_hud_pids" ]]; then
    echo "dinky-notify did not launch the HUD executable" >&2
    exit 1
fi

"$binary" mode main
test ! -e "$notice_file"

if "$binary" --title "Invalid duration" --duration 0 2>/dev/null; then
    echo "dinky-notify accepted a non-positive duration" >&2
    exit 1
fi

for pid in $new_hud_pids; do
    kill "$pid"
    wait "$pid" 2>/dev/null || true
done
new_hud_pids=""

"$binary" end
test -d "$test_home/Library/Application Support/DinkyModeHUD"

if "$binary" >/dev/null 2>&1 &
then
    hud_pid=$!
else
    echo "dinky-notify could not start the HUD without arguments" >&2
    exit 1
fi
sleep 1
if ! kill -0 "$hud_pid" 2>/dev/null; then
    echo "dinky-notify exited instead of keeping the HUD running" >&2
    exit 1
fi
kill "$hud_pid"
wait "$hud_pid" 2>/dev/null || true
unset hud_pid

echo "Release smoke test passed"
