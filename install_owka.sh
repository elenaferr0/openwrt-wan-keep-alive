#!/bin/ash
# Installation script.

REPO_BASE=https://raw.githubusercontent.com/elenaferr0/openwrt-wan-keep-alive/master
DEFAULT_INSTALL_DIR=/usr/openwrt-wan-keep-alive
DEFAULT_LOG_DIR=/usr/openwrt-wan-keep-alive/logs
DEFAULT_DAEMON_NAME=wankeepalive
DEFAULT_DNS1=9.9.9.9
DEFAULT_DNS2=193.110.81.0
DEFAULT_DNS_TRIALS=5
DEFAULT_OFFLINE_THRESHOLD=5
DEFAULT_INTERFACE_RESTART_DELAY=45
DEFAULT_ONLINE_DELAY=120
DEFAULT_LOG_MAX_LINES=11000
DEFAULT_LOG_TRIM_LINES=6000

INSTALL_DIR="$DEFAULT_INSTALL_DIR"
LOG_DIR="$DEFAULT_LOG_DIR"
DAEMON_NAME="$DEFAULT_DAEMON_NAME"
DNS1="$DEFAULT_DNS1"
DNS2="$DEFAULT_DNS2"
DNS_TRIALS="$DEFAULT_DNS_TRIALS"
OFFLINE_THRESHOLD="$DEFAULT_OFFLINE_THRESHOLD"
INTERFACE_RESTART_DELAY="$DEFAULT_INTERFACE_RESTART_DELAY"
ONLINE_DELAY="$DEFAULT_ONLINE_DELAY"
LOG_MAX_LINES="$DEFAULT_LOG_MAX_LINES"
LOG_TRIM_LINES="$DEFAULT_LOG_TRIM_LINES"

prompt_value()
{
	VAR_NAME="$1"
	PROMPT_TEXT="$2"
	DEFAULT_VALUE="$3"
	eval "CURRENT_VALUE=\${$VAR_NAME:-$DEFAULT_VALUE}"
	printf "%s [%s]: " "$PROMPT_TEXT" "$CURRENT_VALUE"
	read ANSWER
	if [ -n "$ANSWER" ]; then
		eval "$VAR_NAME=\$ANSWER"
	else
		eval "$VAR_NAME=\$CURRENT_VALUE"
	fi
}

prompt_yes_no()
{
	PROMPT_TEXT="$1"
	DEFAULT_VALUE="$2"
	while true; do
		printf "%s [%s]: " "$PROMPT_TEXT" "$DEFAULT_VALUE"
		read ANSWER
		if [ -z "$ANSWER" ]; then
			ANSWER="$DEFAULT_VALUE"
		fi
		case "$ANSWER" in
			[Yy]*) return 0 ;;
			[Nn]*) return 1 ;;
			*) echo "Please answer 'y' or 'n'." ;;
		esac
	done
}

echo ""
echo "##### OpenWRT wan-keep-alive #####"
echo ""

prompt_value INSTALL_DIR "Installation folder" "$DEFAULT_INSTALL_DIR"
prompt_value LOG_DIR "Log folder" "$DEFAULT_LOG_DIR"
prompt_value DAEMON_NAME "Daemon name" "$DEFAULT_DAEMON_NAME"
prompt_value DNS1 "Primary DNS server" "$DEFAULT_DNS1"
prompt_value DNS2 "Secondary DNS server" "$DEFAULT_DNS2"
prompt_value DNS_TRIALS "Number of DNS trials" "$DEFAULT_DNS_TRIALS"
prompt_value OFFLINE_THRESHOLD "Offline threshold before reboot" "$DEFAULT_OFFLINE_THRESHOLD"
prompt_value INTERFACE_RESTART_DELAY "Delay after interface restart (seconds)" "$DEFAULT_INTERFACE_RESTART_DELAY"
prompt_value ONLINE_DELAY "Delay between online checks (seconds)" "$DEFAULT_ONLINE_DELAY"
prompt_value LOG_MAX_LINES "Maximum log lines before trim" "$DEFAULT_LOG_MAX_LINES"
prompt_value LOG_TRIM_LINES "Log lines to keep after trim" "$DEFAULT_LOG_TRIM_LINES"

# Check if ncat is installed
NCAT_INSTALLED=$(opkg status ncat | grep "installed")

install_ncat()
{
	echo "Installing ncat (opkg install ncat) ..."
	opkg -V0 update
	opkg install ncat
	echo "ncat is now installed"
}

write_config()
{
	cat > "$INSTALL_DIR/owka.conf" <<EOF
OWKA_DNS1="$DNS1"
OWKA_DNS2="$DNS2"
OWKA_DNS_TRIALS="$DNS_TRIALS"
OWKA_OFFLINE_THRESHOLD="$OFFLINE_THRESHOLD"
OWKA_INTERFACE_RESTART_DELAY="$INTERFACE_RESTART_DELAY"
OWKA_ONLINE_DELAY="$ONLINE_DELAY"
OWKA_LOG_MAX_LINES="$LOG_MAX_LINES"
OWKA_LOG_TRIM_LINES="$LOG_TRIM_LINES"
OWKA_LOG_DIR="$LOG_DIR"
OWKA_LOG_FILE="$LOG_DIR/log.txt"
EOF
}

install_files()
{
	mkdir -p "$INSTALL_DIR"
	mkdir -p "$LOG_DIR"
	touch "$LOG_DIR/log.txt"
	write_config
	echo "Downloading files from $REPO_BASE ..."
	echo "- dns-test.sh"
	wget -q --no-check-certificate "$REPO_BASE/dns-test.sh" -O "$INSTALL_DIR/dns-test.sh" && chmod +x "$INSTALL_DIR/dns-test.sh"
	echo "- wan-keep-alive.sh"
	wget -q --no-check-certificate "$REPO_BASE/wan-keep-alive.sh" -O "$INSTALL_DIR/wan-keep-alive.sh" && chmod +x "$INSTALL_DIR/wan-keep-alive.sh"
	echo "- restart-interface.sh"
	wget -q --no-check-certificate "$REPO_BASE/restart-interface.sh" -O "$INSTALL_DIR/restart-interface.sh" && chmod +x "$INSTALL_DIR/restart-interface.sh"
	echo "- restart-router.sh"
	wget -q --no-check-certificate "$REPO_BASE/restart-router.sh" -O "$INSTALL_DIR/restart-router.sh" && chmod +x "$INSTALL_DIR/restart-router.sh"
	echo "- $DAEMON_NAME"
	wget -q --no-check-certificate "$REPO_BASE/wankeepalive" -O "/etc/init.d/$DAEMON_NAME"
	sed -i "s|^BINFILE=.*|BINFILE=\"$INSTALL_DIR/wan-keep-alive.sh\"|" "/etc/init.d/$DAEMON_NAME"
	chmod +x "/etc/init.d/$DAEMON_NAME"
	echo "..."
	echo "Enabling and starting $DAEMON_NAME script ..."
	"/etc/init.d/$DAEMON_NAME" enable && "/etc/init.d/$DAEMON_NAME" start
}

finish(){
	echo ""
	echo "OpenWRT wan-keep-alive is now installed and ready"
	rm -f install_owka.sh
}

echo "Checking for ncat package: $NCAT_INSTALLED"
if [ "" = "$NCAT_INSTALLED" ]; then
	echo "ncat package is not installed"
	if prompt_yes_no "This will install ncat package as a prerequisite. Do you want to continue (y/n)?" "y"; then
		install_ncat
	else
		echo "Installation aborted by user"
		exit
	fi
fi

echo ""

if prompt_yes_no "This will download the files into $INSTALL_DIR and store logs in $LOG_DIR. Do you want to continue (y/n)?" "y"; then
	install_files
	finish
else
	echo "Installation aborted by user"
	exit
fi
