#!/bin/ash
# Main script file.

DIR=$(cd "$(dirname "$0")" ; pwd -P)
LOG_FILE="$DIR/log.txt"
CONFIG_FILE="$DIR/owka.conf"

if [ -f "$CONFIG_FILE" ]; then
	. "$CONFIG_FILE"
fi

: "${OWKA_OFFLINE_THRESHOLD:=5}"
: "${OWKA_INTERFACE_RESTART_DELAY:=45}"
: "${OWKA_ONLINE_DELAY:=120}"
: "${OWKA_LOG_MAX_LINES:=11000}"
: "${OWKA_LOG_TRIM_LINES:=6000}"

SH_DNS_TESTS="$DIR/dns-test.sh"
SH_RESTART_INTERFACE="$DIR/restart-interface.sh"
SH_RESTART_ROUTER="$DIR/restart-router.sh"

trim_log()
{
	[ -f "$LOG_FILE" ] || return 0
	LINES_COUNT=$(wc -l < "$LOG_FILE")
	if [[ "$LINES_COUNT" -ge "$OWKA_LOG_MAX_LINES" ]]; then
		tail -n "$OWKA_LOG_TRIM_LINES" "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
	fi
}


while true; do
	OFFLINE_COUNT=$(tail -6 "$LOG_FILE" | grep OFFLINE | wc -l)
	trim_log

	# DNS test, it's result defines the ONLINE/OFFLINE state
	"$SH_DNS_TESTS"

	if [ $? -eq 1 ]; then
		echo "Router is offline !."
		echo "$(date) OFFLINE > Restarting interface" >> $LOG_FILE
		trim_log

		if [[ "$OFFLINE_COUNT" -ge "$OWKA_OFFLINE_THRESHOLD" ]]; then
			echo ">> Restarting router in 3min..."
			sleep 1m
			echo ">> Restarting router in 2min..."
			sleep 1m
			echo ">> Restarting router in 1min..."
			sleep 1m
			echo ">> Restarting router..."
			"$SH_RESTART_ROUTER"
		else
			echo ">> Restarting interface..."
			"$SH_RESTART_INTERFACE"
			sleep "$OWKA_INTERFACE_RESTART_DELAY"
		fi
  	else
		echo "Router is online :)"
		echo "$(date) ONLINE" >> $LOG_FILE
		trim_log
		sleep "$OWKA_ONLINE_DELAY"
	fi
done
