#!/system/bin/sh
# Run late, only part of post boot state log
LOG="/cache/bootracer.log"
echo "[$(date)] BOOT CHECKED; failsafe not flagged." >>"$LOG" 2>&1
