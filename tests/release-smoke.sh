#!/bin/bash
set -euo pipefail

binary=${1:?usage: release-smoke.sh /path/to/macnotif}
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
    rm -rf "$test_home"
}
trap cleanup EXIT

export HOME="$test_home"
export CFFIXED_USER_HOME="$test_home"

state_dir="$test_home/Library/Application Support/MacNotif"
permanent_file="$state_dir/permanent.json"
temporary_file="$state_dir/temporary.json"
before_pids=$(pgrep -x "$process_name" 2>/dev/null || true)

"$binary" --title "Persistent notice" --mode permanent
test -f "$permanent_file"
grep -Fq '"title":"Persistent notice"' "$permanent_file"

sleep 1
after_pids=$(pgrep -x "$process_name" 2>/dev/null || true)
for pid in $after_pids; do
    case " $before_pids " in
        *" $pid "*) ;;
        *) new_hud_pids="$new_hud_pids $pid" ;;
    esac
done
if [[ -z "$new_hud_pids" ]]; then
    echo "macnotif did not launch the HUD executable" >&2
    exit 1
fi

"$binary" --title "Temporary notice" --duration 30
test -f "$temporary_file"
grep -Fq '"title":"Temporary notice"' "$temporary_file"

"$binary" --title "Updated release smoke test" --mode permanent
grep -Fq '"title":"Updated release smoke test"' "$permanent_file"
sleep 1
after_pids=$(pgrep -x "$process_name" 2>/dev/null || true)
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
