#!/bin/sh
# This file is responsible for DNS check. The return value of its process determines the ONLINE (exit 0)/OFFLINE (exit 1) state.
# OpenWRT ncat package is used instead of the included busybox "compact" version or outdated netcat package. 

DIR=$(cd "$(dirname "$0")" ; pwd -P)
CONFIG_FILE="$DIR/owka.conf"

if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
fi

: "${OWKA_DNS1:=9.9.9.9}"
: "${OWKA_DNS2:=193.110.81.0}"
: "${OWKA_DNS_TRIALS:=5}"

ONLINE1=0
ONLINE2=0

trial=0
while [ "$trial" -lt "$OWKA_DNS_TRIALS" ]; do
	ncat -G 4 -z "$OWKA_DNS1" 53
	RETVAL1=$?
	if [ "$RETVAL1" -eq 0 ]; then
		ONLINE1=1
	fi
	trial=$((trial + 1))
done

if [ $ONLINE1 -eq 1 ]; then
    # IP1_TO_SCAN is reacheable
    exit 0
fi


trial=0
while [ "$trial" -lt "$OWKA_DNS_TRIALS" ]; do
	ncat -G 4 -z "$OWKA_DNS2" 53
	RETVAL2=$?
	if [ "$RETVAL2" -eq 0 ]; then
		ONLINE2=1
	fi
	trial=$((trial + 1))
done
if [ $ONLINE2 -eq 1 ]; then
    # IP2_TO_SCAN is reacheable
    exit 0
else
    # OFFLINE (connexion is down)
    exit 1
fi
