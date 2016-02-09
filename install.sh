#!/bin/bash
rpm -qa | grep -qw xinetd || yum -y install net-snmp xinetd

## pre-install observium agent and scripts
OBSERVIUM_BASE="https://raw.githubusercontent.com/magenx/observium/master"

wget -qO /etc/xinetd.d/observium_agent ${OBSERVIUM_BASE}/observium_agent_xinetd
wget -qO /usr/bin/observium_agent ${OBSERVIUM_BASE}/observium_agent
wget -qO /usr/bin/distro ${OBSERVIUM_BASE}/distro

mkdir -p /usr/lib/observium_agent/local

wget -qO /usr/lib/observium_agent/local/nginx      ${OBSERVIUM_BASE}/nginx
wget -qO /usr/lib/observium_agent/local/rpm        ${OBSERVIUM_BASE}/rpm
wget -qO /usr/lib/observium_agent/local/mysql      ${OBSERVIUM_BASE}/mysql
wget -qO /usr/lib/observium_agent/local/mysql.cnf  ${OBSERVIUM_BASE}/mysql.cnf

chmod +x /usr/bin/observium_agent /etc/xinetd.d/observium_agent /usr/bin/distro /usr/lib/observium_agent/local/*

## configure snmpd user and auth
echo
read -e -p "---> Enter your observium server IP address: " -i "1.2.3.4" OBSERVIUM
sed -i "s/OBSERVIUM_IP/${OBSERVIUM}/" /etc/xinetd.d/observium_agent

service snmpd stop >/dev/null 2>&1
echo
read -e -p "---> Enter SNMPD service username: " -i "USERNAME" SNMPD_USERNAME
read -e -p "---> Enter SNMPD service location: " -i "Paris, France" SNMPD_LOCATION
read -e -p "---> Enter SNMPD service contact name: " -i "MagenX" SNMPD_NAME
read -e -p "---> Enter SNMPD service contact email: " -i "admin@magenx.com" SNMPD_EMAIL

MD5_CODE=$(head -c 500 /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
AES_CODE=$(head -c 500 /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
echo
sed -i "/syscontact Root/ a\
extend .1.3.6.1.4.1.2021.7890.1 distro /usr/bin/distro" /etc/snmp/snmpd.conf

sed -i "s/.*syslocation Unknown.*/syslocation ${SNMPD_LOCATION}/" /etc/snmp/snmpd.conf
sed -i "s/.*syscontact Root.*/syscontact ${SNMPD_NAME} <${SNMPD_EMAIL}>/" /etc/snmp/snmpd.conf

net-snmp-create-v3-user -ro -A ${MD5_CODE} -X ${AES_CODE} -a MD5 -x AES ${SNMPD_USERNAME}
echo
echo "MD5_CODE ${MD5_CODE}"
echo "AES_CODE ${AES_CODE}"
echo
if [ -f /etc/csf/csf.allow ]; then
echo "udp|out|d=1514|d=${OBSERVIUM}" >> /etc/csf/csf.allow
echo "udp|in|d=161|s=${OBSERVIUM}"   >> /etc/csf/csf.allow
echo "tcp|in|d=36602|s=${OBSERVIUM}" >> /etc/csf/csf.allow
csf -a ${OBSERVIUM}
csf -x  >/dev/null 2>&1
csf -e  >/dev/null 2>&1
fi

service snmpd restart >/dev/null 2>&1
service xinetd restart >/dev/null 2>&1

