#!/bin/bash

### BEGIN INIT INFO
# Provides:          anonsurf
# Required-Start:
# Required-Stop:
# Should-Start:
# Default-Start:
# Default-Stop:
# Short-Description: Transparent Proxy through TOR.
### END INIT INFO
#
# Devs:
# Lorenzo 'EclipseSpark' Faletra <eclipse@frozenbox.org>
# Lisetta 'Sheireen' Ferrero <sheireen@frozenbox.org>
# Francesco 'mibofra'/'Eli Aran'/'SimpleSmibs' Bonanno <mibofra@ircforce.tk> <mibofra@frozenbox.org>
#
#
# anonsurf is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
# You can get a copy of the license at www.gnu.org/licenses
#
# anonsurf is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Parrot Security OS. If not, see <http://www.gnu.org/licenses/>.


export BLUE='\033[1;94m'
export GREEN='\033[1;92m'
export RED='\033[1;91m'
export RESETCOLOR='\033[1;00m'

# Destinations you don't want routed through Tor
TOR_EXCLUDE="192.168.0.0/16 172.16.0.0/12 10.0.0.0/8"

# The UID Tor runs as
# change it if, starting tor, the command 'ps -e | grep tor' returns a different UID
TOR_UID="0"

# Tor's TransPort
TOR_PORT="9040"


function notify {
	if [ -e /usr/bin/notify-send ]; then
		/usr/bin/notify-send "AnonSurf" "$1"
	fi
}
export notify


function init {
	echo -e -n " $GREEN*$BLUE killing dangerous applications"
	killall -q chrome dropbox iceweasel skype icedove thunderbird firefox firefox-esr chromium xchat hexchat transmission steam
	notify "dangerous applications killed"
	
	echo -e -n " $GREEN*$BLUE cleaning some dangerous cache elements"
	bleachbit -c adobe_reader.cache chromium.cache chromium.current_session chromium.history elinks.history emesene.cache epiphany.cache firefox.url_history flash.cache flash.cookies google_chrome.cache google_chrome.history  links2.history opera.cache opera.search_history opera.url_history &> /dev/null
	notify "cache cleaned"
}




function starti2p {
	echo -e -n " $GREEN*$BLUE starting I2P services"
	service tor stop
	killall tor
	cp /etc/resolv.conf /etc/resolv.conf.bak
	touch /etc/resolv.conf
	echo -e 'nameserver 127.0.0.1\nnameserver 92.222.97.144\nnameserver 92.222.97.145' > /etc/resolv.conf
	echo -e " $GREEN*$BLUE Modified resolv.conf to use localhost and FrozenDNS"
	sudo -u i2psvc i2prouter start
	iceweasel http://127.0.0.1:7657/home &
	notify "I2P daemon started"
}

function stopi2p {
	echo -e -n " $GREEN*$BLUE stopping I2P services"
	sudo -u i2psvc i2prouter stop
	if [ -e /etc/resolv.conf.bak ]; then
		rm /etc/resolv.conf
		cp /etc/resolv.conf.bak /etc/resolv.conf
	fi
	notify "I2P daemon stopped"
}



function ip {

	echo -e "\nMy ip is:\n"
	sleep 1
	wget -qO- http://ip.frozenbox.org/
	echo -e "\n\n----------------------------------------------------------------------"
}



function start {
	# Make sure only root can run this script
	if [ $(id -u) -ne 0 ]; then
		echo -e -e "\n$GREEN[$RED!$GREEN] $RED R U DRUNK?? This script must be run as root$RESETCOLOR\n" >&2
		exit 1
	fi
	
	echo -e "\n$GREEN[$BLUE i$GREEN ]$BLUE Starting anonymous mode:$RESETCOLOR\n"
	
	if [ ! -e /etc/anonsurf/tor.pid ]; then
		echo -e " $RED*$BLUE Tor is not running! $GREEN starting it $BLUE for you\n" >&2
		echo -e -n " $GREEN*$BLUE Service " 
		service nscd stop
		service dnsmasq stop
		killall dnsmasq nscd
		echo -e " $GREEN*$BLUE It is safe to not worry for dnsmasq and nscd stop errors if they are not installed or stopped already."
		sleep 4
		tor -f /etc/anonsurf/torrc
		sleep 6
	fi
	if ! [ -f /etc/network/iptables.rules ]; then
		iptables-save > /etc/network/iptables.rules
		echo -e " $GREEN*$BLUE Saved iptables rules"
	fi
	
	iptables -F
	iptables -t nat -F
	
	cp /etc/resolv.conf /etc/resolv.conf.bak
	touch /etc/resolv.conf
	echo -e 'nameserver 127.0.0.1\nnameserver 92.222.97.144\nnameserver 92.222.97.145' > /etc/resolv.conf
	echo -e " $GREEN*$BLUE Modified resolv.conf to use Tor and FrozenDNS"

	# set iptables nat
	iptables -t nat -A OUTPUT -m owner --uid-owner $TOR_UID -j RETURN

	#set dns redirect
	iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 53
	iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports 53
	iptables -t nat -A OUTPUT -p udp -m owner --uid-owner $TOR_UID -m udp --dport 53 -j REDIRECT --to-ports 53
	
	#resolve .onion domains mapping 10.192.0.0/10 address space
	iptables -t nat -A OUTPUT -p tcp -d 10.192.0.0/10 -j REDIRECT --to-ports $TOR_PORT
	iptables -t nat -A OUTPUT -p udp -d 10.192.0.0/10 -j REDIRECT --to-ports $TOR_PORT
	
	#exclude local addresses
	for NET in $TOR_EXCLUDE 127.0.0.0/9 127.128.0.0/10; do
		iptables -t nat -A OUTPUT -d $NET -j RETURN
	done
	
	#redirect all other output through TOR
	iptables -t nat -A OUTPUT -p tcp --syn -j REDIRECT --to-ports $TOR_PORT
	iptables -t nat -A OUTPUT -p udp -j REDIRECT --to-ports $TOR_PORT
	iptables -t nat -A OUTPUT -p icmp -j REDIRECT --to-ports $TOR_PORT
	
	#accept already established connections
	iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
	
	#exclude local addresses
	for NET in $TOR_EXCLUDE 127.0.0.0/8 127.0.1.0/8; do
		iptables -A OUTPUT -d $NET -j ACCEPT
	done
	
	#allow only tor output
	iptables -A OUTPUT -m owner --uid-owner $TOR_UID -j ACCEPT
	iptables -A OUTPUT -j REJECT

	echo -e "$GREEN *$BLUE All traffic was redirected throught Tor\n"
	echo -e "$GREEN[$BLUE i$GREEN ]$BLUE You are under AnonSurf tunnel$RESETCOLOR\n"
	notify "Global Anonymous Proxy Activated"
	sleep 4
}





function stop {
	# Make sure only root can run our script
	if [ $(id -u) -ne 0 ]; then
		echo -e "\n$GREEN[$RED!$GREEN] $RED R U DRUNK?? This script must be run as root$RESETCOLOR\n" >&2
		exit 1
	fi
	echo -e "\n$GREEN[$BLUE i$GREEN ]$BLUE Stopping anonymous mode:$RESETCOLOR\n"

	iptables -F
	iptables -t nat -F
	echo -e " $GREEN*$BLUE Deleted all iptables rules"
	
	if [ -f /etc/network/iptables.rules ]; then
		iptables-restore < /etc/network/iptables.rules
		rm /etc/network/iptables.rules
		echo -e " $GREEN*$BLUE Iptables rules restored"
	fi
	echo -e -n " $GREEN*$BLUE Service "
	if [ -e /etc/resolv.conf.bak ]; then
		rm /etc/resolv.conf
		cp /etc/resolv.conf.bak /etc/resolv.conf
	fi
	pkill /etc/anonsurf/tor.pid && rm -f /etc/anonsurf/tor.pid
	killall tor && rm -f /etc/anonsurf/tor.pid
	sleep 6
	service resolvconf start || service resolvconf restart
	service dnsmasq start
	service nscd start
	echo -e " $GREEN*$BLUE It is safe to not worry for dnsmasq and nscd start errors if they are not installed or started already."
	sleep 1
	
	echo -e " $GREEN*$BLUE Anonymous mode stopped\n"
	notify "Global Anonymous Proxy Stopped"
	sleep 4
}

function change {
	pkill /etc/anonsurf/tor.pid && rm -f /etc/anonsurf/tor.pid
	sleep 4
	echo -e " $GREEN*$BLUE Tor daemon reloaded and forced to change nodes\n"
	notify "Identity changed"
	sleep 1
}

function status {
	cat /tmp/anonsurf.log
}

case "$1" in
	start)
		init
		start
	;;
	stop)
		init
		stop
	;;
	change)
		change
	;;
	status)
		status
	;;
	myip)
		ip
	;;
	firefox_tor)
		firefox_tor
	;;
	starti2p)
		starti2p
	;;
	stopi2p)
		stopi2p
	;;
	restart)
		$0 stop
		sleep 1
		$0 start
	;;
   *)
echo -e "
Parrot AnonSurf Module (v 2.2)
	Usage:
	$RED┌──[$GREEN$USER$YELLOW@$BLUE`hostname`$RED]─[$GREEN$PWD$RED]
	$RED└──╼ \$$GREEN"" anonsurf $RED{$GREEN""start$RED|$GREEN""stop$RED|$GREEN""restart$RED|$GREEN""change$RED""$RED|$GREEN""status$RED""}
	
	$RED start$BLUE -$GREEN Start system-wide anonymous
		  tunneling under TOR proxy through iptables	  
	$RED stop$BLUE -$GREEN Reset original iptables settings
		  and return to clear navigation
	$RED restart$BLUE -$GREEN Combines \"stop\" and \"start\" options
	$RED change$BLUE -$GREEN Changes identity restarting TOR
	$RED status$BLUE -$GREEN Check if AnonSurf is working properly
	----[ I2P related features ]----
	$RED starti2p$BLUE -$GREEN Start i2p services
	$RED stopi2p$BLUE -$GREEN Stop i2p services
	
$RESETCOLOR" >&2
exit 1
;;
esac

echo -e $RESETCOLOR
exit 0
