#!/bin/sh

HOME_DIR=/opt/work

if [ -z "${NETCONF_USER}" ]; then
    echo "Environment variable NETCONF_USER is required."
    exit 1
fi

if [ -z "${NETCONF_PASSWORD}" ]; then
    echo "Environment variable NETCONF_PASSWORD is required."
    exit 1
fi

if [ -n "${LOCAL_UID}" ]; then
    useradd -m -u ${LOCAL_UID:-1000} -d ${HOME_DIR} -s /bin/bash ${NETCONF_USER}
else
    useradd -m -d ${HOME_DIR} -s /bin/bash ${NETCONF_USER}
fi

echo ${NETCONF_USER}:${NETCONF_PASSWORD} | chpasswd

sed -e "/^Port /d" /etc/ssh/sshd_config > tmp.txt
mv -f tmp.txt /etc/ssh/sshd_config
echo "Port ${NETCONF_PORT:-830}" >> /etc/ssh/sshd_config

mkdir -p ${HOME_DIR}/data/log
mkdir -p ${HOME_DIR}/data/ds
cp -n ${HOME_DIR}/initial-data/* /${HOME_DIR}/data/ds
chown -R ${NETCONF_USER} ${HOME_DIR}/data

/usr/sbin/sshd -D
