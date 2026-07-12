#!/usr/bin/env bash
#
# update-system.sh — Parallelized system updater for Arch/CachyOS + Hyprland
#
# STRATEGY (minimize wall-clock time, without racing anything unsafe):
#
#   1. pacman downloads all official-repo updates WITHOUT installing (-w).
#      This is the only phase that competes for your download bandwidth,
#      so nothing else starts until it's finished.
#
#   2. The instant that download finishes, two things start at once:
#        a) pacman installs the already-downloaded packages (disk/CPU only,
#           no network)
#        b) your AUR helper (yay/paru) downloads, builds and installs AUR
#           updates. Running these together is safe for bandwidth because
#           pacman's install step no longer touches the network — this is
#           the actual time-saving step.
#
#   3. Once AUR is completely finished, flatpak updates, then snap updates,
#      run one after another.
#
# Anything you don't have installed (yay/paru, flatpak, snap) is skipped
# automatically.
#
# CAVEATS (read once):
#   - AUR helpers don't offer a clean "download only" mode the way pacman's
#     -w does, so flatpak starts after AUR is fully built+installed, not
#     merely downloaded. Trying to detect that sub-phase would mean parsing
#     yay/paru's human-readable output, which breaks across versions/locales
#     — not worth the fragility.
#   - To run the AUR helper unattended in the background, this script
#     auto-accepts diffs/prompts (--noconfirm + answer flags). You lose the
#     manual "review the PKGBUILD" step. If you like reviewing AUR changes,
#     do it separately/periodically instead of relying on this script.
#   - In theory, pacman's install step and the AUR helper's final install
#     step could both want the pacman DB lock at the same moment. In
#     practice this essentially never happens because building AUR packages
#     takes far longer than installing already-cached repo packages, but if
#     you ever see "unable to lock database", just re-run the script.
#
set -uo pipefail

# ---------- options ----------
SKIP_AUR=0
SKIP_FLATPAK=0
SKIP_SNAP=0
NOTIFY=1

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

  --no-aur        Skip AUR updates even if a helper is installed
  --no-flatpak    Skip flatpak updates
  --no-snap       Skip snap updates
  --no-notify     Don't send a desktop notification when finished
  -h, --help      Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-aur) SKIP_AUR=1 ;;
        --no-flatpak) SKIP_FLATPAK=1 ;;
        --no-snap) SKIP_SNAP=1 ;;
        --no-notify) NOTIFY=0 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
    shift
done

# ---------- logging helpers ----------
C_BLUE='\033[1;34m'; C_GREEN='\033[1;32m'; C_RED='\033[1;31m'; C_YELLOW='\033[1;33m'; C_RESET='\033[0m'

log()  { echo -e "${C_BLUE}[*]${C_RESET} $*"; }
ok()   { echo -e "${C_GREEN}[✓]${C_RESET} $*"; }
warn() { echo -e "${C_YELLOW}[!]${C_RESET} $*"; }
fail() { echo -e "${C_RED}[✗]${C_RESET} $*" >&2; }

section() {
    echo
    echo -e "${C_BLUE}== $* ==${C_RESET}"
}

human_time() {
    local s=$1
    printf '%dm%02ds' $((s / 60)) $((s % 60))
}

SCRIPT_START=$(date +%s)

# ---------- detect what we have ----------
AUR_HELPER=""
if [[ $SKIP_AUR -eq 0 ]]; then
    for helper in yay paru; do
        if command -v "$helper" &>/dev/null; then
            AUR_HELPER="$helper"
            break
        fi
    done
fi

HAS_FLATPAK=0
[[ $SKIP_FLATPAK -eq 0 ]] && command -v flatpak &>/dev/null && HAS_FLATPAK=1

HAS_SNAP=0
[[ $SKIP_SNAP -eq 0 ]] && command -v snap &>/dev/null && HAS_SNAP=1

# ---------- sudo keep-alive ----------
log "Requesting sudo access up front (needed for pacman/snap)..."
if ! sudo -v; then
    fail "Could not get sudo access. Aborting."
    exit 1
fi
# Refresh the sudo timestamp in the background so the concurrent pacman /
# AUR-helper sudo calls later don't hit a stale timestamp and re-prompt.
( while true; do sudo -n -v; sleep 60; done ) &
SUDO_KEEPALIVE_PID=$!
trap '
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
    [[ -n "${AUR_PID:-}" ]] && kill "$AUR_PID" 2>/dev/null
    [[ -n "${PACMAN_INSTALL_PID:-}" ]] && kill "$PACMAN_INSTALL_PID" 2>/dev/null
' EXIT INT TERM

PACMAN_DL_STATUS=0
PACMAN_INSTALL_STATUS=0
AUR_STATUS=0
FLATPAK_STATUS=0
SNAP_STATUS=0

# ---------- phase 1: pacman, download only ----------
if [[ -n "$AUR_HELPER" ]]; then
    # Splitting download/install only pays off if something else can run
    # during the install step — i.e. if there's an AUR helper to run.
    section "Phase 1/3 — pacman: downloading official repo updates"
    T0=$(date +%s)
    sudo pacman -Syuw --noconfirm
    PACMAN_DL_STATUS=$?
    T1=$(date +%s)
    if [[ $PACMAN_DL_STATUS -eq 0 ]]; then
        ok "pacman downloads finished in $(human_time $((T1 - T0)))"
    else
        fail "pacman download phase failed (exit $PACMAN_DL_STATUS)"
        exit 1
    fi

    # ---------- phase 2: pacman install + AUR update, in parallel ----------
    section "Phase 2/3 — installing pacman updates + AUR updates (parallel)"
    T0=$(date +%s)

    log "Starting pacman install (from cache, no network use)..."
    sudo pacman -Su --noconfirm &
    PACMAN_INSTALL_PID=$!

    log "Starting AUR update via $AUR_HELPER (noninteractive)..."
    case "$AUR_HELPER" in
        yay)
            "$AUR_HELPER" -Sua --noconfirm \
                --answerclean None --answerdiff None \
                --answeredit None --answerupgrade All &
            ;;
        paru)
            "$AUR_HELPER" -Sua --noconfirm --skipreview &
            ;;
    esac
    AUR_PID=$!

    wait "$PACMAN_INSTALL_PID"
    PACMAN_INSTALL_STATUS=$?
    wait "$AUR_PID"
    AUR_STATUS=$?

    T1=$(date +%s)
    if [[ $PACMAN_INSTALL_STATUS -eq 0 ]]; then
        ok "pacman install finished"
    else
        fail "pacman install failed (exit $PACMAN_INSTALL_STATUS)"
    fi
    if [[ $AUR_STATUS -eq 0 ]]; then
        ok "AUR update finished"
    else
        fail "AUR update failed (exit $AUR_STATUS)"
    fi
    log "Phase 2 total: $(human_time $((T1 - T0)))"
else
    # No AUR helper (or --no-aur): no benefit to splitting download/install,
    # just do a normal full upgrade.
    section "Phase 1-2/3 — pacman: full system upgrade"
    [[ $SKIP_AUR -eq 1 ]] && log "AUR updates skipped (--no-aur)."
    [[ $SKIP_AUR -eq 0 ]] && warn "No AUR helper (yay/paru) found — skipping AUR updates."
    T0=$(date +%s)
    sudo pacman -Syu --noconfirm
    PACMAN_INSTALL_STATUS=$?
    T1=$(date +%s)
    if [[ $PACMAN_INSTALL_STATUS -eq 0 ]]; then
        ok "pacman upgrade finished in $(human_time $((T1 - T0)))"
    else
        fail "pacman upgrade failed (exit $PACMAN_INSTALL_STATUS)"
    fi
fi

# ---------- phase 3: flatpak, then snap ----------
section "Phase 3/3 — flatpak, then snap"

if [[ $HAS_FLATPAK -eq 1 ]]; then
    log "Updating flatpak packages..."
    T0=$(date +%s)
    flatpak update -y
    FLATPAK_STATUS=$?
    T1=$(date +%s)
    if [[ $FLATPAK_STATUS -eq 0 ]]; then
        ok "flatpak updated in $(human_time $((T1 - T0)))"
    else
        fail "flatpak update failed (exit $FLATPAK_STATUS)"
    fi
elif [[ $SKIP_FLATPAK -eq 1 ]]; then
    log "flatpak skipped (--no-flatpak)."
else
    log "flatpak not installed — skipping."
fi

if [[ $HAS_SNAP -eq 1 ]]; then
    log "Updating snap packages..."
    T0=$(date +%s)
    sudo snap refresh
    SNAP_STATUS=$?
    T1=$(date +%s)
    if [[ $SNAP_STATUS -eq 0 ]]; then
        ok "snap updated in $(human_time $((T1 - T0)))"
    else
        fail "snap update failed (exit $SNAP_STATUS)"
    fi
elif [[ $SKIP_SNAP -eq 1 ]]; then
    log "snap skipped (--no-snap)."
else
    log "snap not installed — skipping."
fi

# ---------- summary ----------
SCRIPT_END=$(date +%s)
TOTAL=$((SCRIPT_END - SCRIPT_START))

section "Summary"
echo "Total time: $(human_time $TOTAL)"

OVERALL_STATUS=0
for pair in "pacman-download:$PACMAN_DL_STATUS" "pacman-install:$PACMAN_INSTALL_STATUS" \
            "aur:$AUR_STATUS" "flatpak:$FLATPAK_STATUS" "snap:$SNAP_STATUS"; do
    name="${pair%%:*}"
    status="${pair##*:}"
    if [[ "$status" -ne 0 ]]; then
        fail "$name failed (exit $status)"
        OVERALL_STATUS=1
    fi
done
[[ $OVERALL_STATUS -eq 0 ]] && ok "Everything updated successfully."

if [[ $NOTIFY -eq 1 ]] && command -v notify-send &>/dev/null; then
    if [[ $OVERALL_STATUS -eq 0 ]]; then
        notify-send "System update complete" "Finished in $(human_time $TOTAL)" 2>/dev/null || true
    else
        notify-send -u critical "System update finished with errors" "Check the terminal output" 2>/dev/null || true
    fi
fi

exit $OVERALL_STATUS
