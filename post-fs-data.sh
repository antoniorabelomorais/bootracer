#!/system/bin/sh
# Failsafe Bootloop Guard - post-fs-data
set -eu

STATE_DIR="/data/adb/bootracer"
LOG="/cache/bootracer.log"
MODS_DIR="/data/adb/modules"
SVC_DIR="/data/adb/service.d"
PFS_DIR="/data/adb/post-fs-data.d"

# Params
WINDOW_SEC=300        # Time Window to count (Default 5mins)
THRESHOLD=3           # if default 3 reboots in time window => flag failsafe

mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

# allow override with simple covfig file (KEY=VALUE)
CFG="$STATE_DIR/config"
if [ -f "$CFG" ]; then
  # shellcheck disable=SC1090
  . "$CFG" || true
fi

now="$(date +%s 2>/dev/null || busybox date +%s)"
[ -n "${now:-}" ] || now=0

COUNT_FILE="$STATE_DIR/count"
START_FILE="$STATE_DIR/window_start"

count=0
start="$now"

if [ -f "$COUNT_FILE" ]; then
  count="$(cat "$COUNT_FILE" 2>/dev/null || echo 0)"
fi
if [ -f "$START_FILE" ]; then
  start="$(cat "$START_FILE" 2>/dev/null || echo "$now")"
fi

# Restart window if time already passed
delta=$(( now - start ))
if [ "$delta" -gt "$WINDOW_SEC" ] || [ "$delta" -lt 0 ]; then
  start="$now"
  count=0
fi

count=$(( count + 1 ))
echo "$count" > "$COUNT_FILE"
echo "$start" > "$START_FILE"

# manual triggers (create one of these files to trigger the failsafe on next boot)
if [ -f "/cache/.failsafe_trigger" ] || [ -f "/sdcard/.failsafe_trigger" ]; then
  count="$THRESHOLD"
fi

if [ "$count" -ge "$THRESHOLD" ]; then
  {
    echo "[$(date)] Failsafe triggered: $count boots em ${delta}s"
    echo "turning off modules and scripts…"
  } >>"$LOG" 2>&1

  # Rem 1) Turn Off all Magisk Modules
  if [ -d "$MODS_DIR" ]; then
    for d in "$MODS_DIR"/*; do
      [ -d "$d" ] || continue
      touch "$d/disable" 2>/dev/null || true
      echo "module disabled: $(basename "$d")" >>"$LOG" 2>&1
    done
  fi

  # Rem 2) Turn off User boot scripts
  if [ -d "$SVC_DIR" ]; then
    mv "$SVC_DIR" "${SVC_DIR}.disabled-$(date +%s)" 2>>"$LOG" || true
  fi
  if [ -d "$PFS_DIR" ]; then
    mv "$PFS_DIR" "${PFS_DIR}.disabled-$(date +%s)" 2>>"$LOG" || true
  fi

  # Rem 3) Reset Count and restart
  echo 0 > "$COUNT_FILE"
  echo "$now" > "$START_FILE"

  echo "Restarting…" >>"$LOG"
  reboot
fi
