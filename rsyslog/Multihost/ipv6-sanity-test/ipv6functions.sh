#!/bin/bash

# Description: various functions for ipv6 sanity testing
# Author: Karel Srot <ksrot@redhat.com>

# default network interface
export IF=`netstat -r | grep default | awk '{ print $NF }'`

# directory that contains details about network interfaces
export IFCONFIG_DIR=`mktemp -d`

export PORT=6666

# exposes ifconfig output on port 80
function exposeIfconfig() {

  ifconfig $IF > $IFCONFIG_DIR/localhost  # save interface details
  ln -s $IFCONFIG_DIR/localhost $IFCONFIG_DIR/$HOSTNAME

  # provide ifconfig via nc as long as the IFCONFIG file exists
  while test -f $IFCONFIG_DIR/localhost; do
    nc -l $PORT < $IFCONFIG_DIR/localhost;
  done &

}

# stops ifconfig exposure
function hideIfconfig() {

  rm -f $IFCONFIG_DIR/localhost
  kill `pidof nc`
  sleep 3

}

# reads and saves ifconfig obtained the server (arg 1)
# args: server
function readIfconfig() {

  local SERVERNAME

  SERVERNAME=$1
  echo "Saving to $IFCONFIG_DIR/$SERVERNAME"
  nc $1 $PORT > $IFCONFIG_DIR/$SERVERNAME && cat $IFCONFIG_DIR/$SERVERNAME

}

# parses IPv6 address from the saved ifconfig details 
# args:  server [Global|Site|Link|...]
function getIP6Addr() {

  local SERVERNAME SCOPE

  SERVERNAME=$1
  SCOPE="Global|Site"
  [ -z "$2" ] || SCOPE=$2
  
  # parse the address from the file
  egrep "Scope:($SCOPE)" $IFCONFIG_DIR/$SERVERNAME | sort -k 4 | awk '/inet6/ {print $3 }' | cut -d '/' -f 1 | head -n 1

}


# parses IPv4 address from the saved ifconfig details 
# args:  server 
function getIP4Addr() {

  local SERVERNAME

  SERVERNAME=$1
  # parse the address from the file
  awk '/inet addr/ {print $2 }' $IFCONFIG_DIR/$SERVERNAME | cut -d ':' -f 2

}


# adds a dns record of the server to /etc/hosts
# args: server
function addIP6ToHosts() {
  
  local SERVER IP

  SERVER=$1
  IP=`getIP6Addr $SERVER`
  echo $SERVER $IP
  echo -e "\n$IP $SERVER" >> /etc/hosts

}


# prepare server for the test
# client hostname stored in CLIENTS global var
function prepareServer() {

  local PEERNAME PEER_IP

  PEERNAME=$CLIENTS
 
  rlLog "SERVER: $HOSTNAME (me)"
  rlLog "CLIENT: $PEERNAME"
 
  rlServiceStop iptables
  rlServiceStop ip6tables

  rlRun "exposeIfconfig" 0 "Expose my ifconfig"
  rlRun "rhts-sync-set -s SERVER_EXPOSED"
  rlRun "rhts-sync-block -s CLIENT_QUERY_DONE $PEERNAME" 0 "Waiting till CLIENT reads SERVER configuration"

  rlRun "readIfconfig ${PEERNAME}" 0 "Read CLIENT configuration"
  cp -p /etc/hosts /etc/hosts.ipv6test
  rlRun "addIP6ToHosts ${HOSTNAME}" 0 "Adding ${HOSTNAME} to /etc/hosts" 
  rlRun "addIP6ToHosts ${PEERNAME}" 0 "Adding ${PEERNAME} to /etc/hosts" 

  PEER_IP=`getIP6Addr $PEERNAME`
  rlRun "rhts-sync-set -s SERVER_PING_READY"
  rlRun "rhts-sync-block -s CLIENT_PING_DONE $PEERNAME"

  rlRun "ping6 -c 1 $PEER_IP" 0 "Trying to ping CLIENT using IP $PEER_IP"
  rlRun "ping6 -c 1 $PEERNAME" 0 "Trying to ping CLIENT using hostname through IPv6"

  rlRun "rhts-sync-set -s SERVER_TEST_READY" 0 "SERVER ready for the test"
}

# prepare client for the test
# client hostname stored in CLIENTS global var
function prepareClient() {

  local PEERNAME PEER_IP

  PEERNAME=$SERVERS
 
  rlLog "SERVER: $PEERNAME"
  rlLog "CLIENT: $HOSTNAME (me)"
 
  rlServiceStop iptables
  rlServiceStop ip6tables

  rlRun "exposeIfconfig" 0 "Expose my ifconfig"

  rlRun "rhts-sync-block -s SERVER_EXPOSED $PEERNAME" 0 "Wait for SERVER configuration"
  rlRun "readIfconfig $PEERNAME" 0 "Read SERVER configuration"
  cp -p /etc/hosts /etc/hosts.ipv6test
  rlRun "addIP6ToHosts ${HOSTNAME}" 0 "Adding ${HOSTNAME} to /etc/hosts" 
  rlRun "addIP6ToHosts ${PEERNAME}" 0 "Adding ${PEERNAME} to /etc/hosts" 

  PEER_IP=`getIP6Addr $PEERNAME`

  rlRun "rhts-sync-set -s CLIENT_QUERY_DONE"
  rlRun "rhts-sync-block -s SERVER_PING_READY $PEERNAME"

  rlRun "ping6 -c 1 $PEER_IP" 0 "Trying to ping SERVER using IP $PEER_IP"
  rlRun "ping6 -c 1 $PEERNAME" 0 "Trying to ping SERVER using hostname through IPv6"
  rlRun "rhts-sync-set -s CLIENT_PING_DONE"

  rlRun "rhts-sync-block -s SERVER_TEST_READY $PEERNAME" 0 "waiting till both SERVER and CLIENT ready for the test"

}



# clean server after the test
function cleanMachine() {
  rlRun "hideIfconfig" 0 "Stopping ifconfig exposure"
  rlRun "mv /etc/hosts.ipv6test /etc/hosts; restorecon /etc/hosts" 0 "Restore /etc/hosts file"
  rlRun "rm -rf $IFCONFIG_DIR" 0 "Removing $IFCONFIG_DIR"
}


# disables ipv4 interface
function disableIP4() {
  
  ifconfig $IF 0.0.0.0
  # kill dhclient for $IF
  #kill `ps -ef | grep dhclient | awk '/$IF/ {print $2}'`
  kill `pidof dhclient`

}

# configure ipv4 interface using dhclient
function enableIP4() {

  dhclient $IF

}


