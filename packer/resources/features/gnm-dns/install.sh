#!/bin/bash
# Install DNS routing to the Guardian DNS servers
# This script must be run as root
set -e

# Make sure dnsmasq is installed
if ! (dpkg -s dnsmasq 2> /dev/null > /dev/null); then
    apt-get install -y dnsmasq
fi

# Generate the config file
PROXIES=( "10.252.63.100" "10.253.63.100" )
DOMAINS=( "guprod.gnl" "dc1.gnm" "dc2.gnm" "dmz.gnl" "gws.gutools.co.uk" \
  "252.10.in-addr.arpa" "253.10.in-addr.arpa" "235.10.in-addr.arpa" \
  "236.10.in-addr.arpa" "dev-gutools.co.uk" )
DNSMASQ_GNM_CONF="/etc/dnsmasq.d/gnm.conf"

cat > ${DNSMASQ_GNM_CONF} <<-END
# this file is generated by gnm-dns.sh from github.com/guardian/machine-images

END

for domain in ${DOMAINS[@]}; do
  for proxy in ${PROXIES[@]}; do
    echo "server=/${domain}/${proxy}" >> ${DNSMASQ_GNM_CONF}
  done
done

# Restart - in case we want to use it immediately
service dnsmasq restart
