#!/bin/bash

#Descarga y configura borg y borg_config en un servidor

#Revisar si esta instalado curl o wget
CURL=$(command -v curl)
WGET=$(command -v wget)
if [ ! "$CURL" ] && [ ! "$WGET" ]; then
    echo "Instalar curl antes de continuar";
    echo "Como descargaste este script?";
    exit ;
fi

#Instalar borg
#Es necesario al menos la version 1.1 (aqui instalamos descargando el binario)
#En buster se puede instalar por apt, en stretch activando stretch-backports
apt-get update; apt-get install dialog -y
echo "Instalando borgbackup"
if  [ "$CURL" ]; then
    curl --insecure -sL https://github.com/borgbackup/borg/releases/download/1.2.8/borg-linux64 -o /usr/local/bin/borg
else
    wget --no-check-certificate -q https://github.com/borgbackup/borg/releases/download/1.2.8/borg-linux64 -O /usr/local/bin/borg
fi
chown root:root /usr/local/bin/borg
chmod 755 /usr/local/bin/borg

#Descargar borgcron
echo "Instalando script de Lunix: borgcron"
mkdir -p /etc/lunix/borg/
if  [ "$CURL" ]; then
    curl --insecure -sL https://raw.githubusercontent.com/avillalba96/borg_config/master/borgcron -o /etc/lunix/borg/borgcron-local
else
    wget --no-check-certificate -q https://raw.githubusercontent.com/avillalba96/borg_config/master/borgcron -O /etc/lunix/borg/borgcron-local
fi

chmod 600 -R /etc/lunix/borg
cp /etc/lunix/borg/borgcron-local /etc/lunix/borg/borgcron-lunix
sed -i "s/borgcron-local.conf/borgcron-lunix.conf/g" /etc/lunix/borg/borgcron-lunix
sed -i "s/borg_status-local/borg_status-lunix/g" /etc/lunix/borg/borgcron-lunix
chmod +x /etc/lunix/borg/borgcron-*

echo "Instalando script de Lunix: borgcron logrotate"
if  [ "$CURL" ]; then
    curl --insecure -sL https://raw.githubusercontent.com/avillalba96/borg_config/master/borg_logrotate -o /etc/logrotate.d/borg
else
    wget --no-check-certificate -q https://raw.githubusercontent.com/avillalba96/borg_config/master/borg_logrotate -O /etc/logrotate.d/borg
fi

#Descargar borg_tools
if  [ "$CURL" ]; then
    curl --insecure -sL https://raw.githubusercontent.com/avillalba96/borg_config/master/borg_tools -o /usr/local/sbin/borg_tools
else
    wget --no-check-certificate -q https://raw.githubusercontent.com/avillalba96/borg_config/master/borg_tools -O /usr/local/sbin/borg_tools
fi
chmod +x /usr/local/sbin/borg_tools

#Carpeta para logs
mkdir /var/log/borg
#Cron
echo "Agregando cron"
touch /var/spool/cron/crontabs/root
echo "" >> /var/spool/cron/crontabs/root
echo "#Borg Backup" >> /var/spool/cron/crontabs/root
echo "#0 0 * * * /etc/lunix/borg/borgcron-lunix > /dev/null 2>&1" >> /var/spool/cron/crontabs/root
echo "0 1 * * * /etc/lunix/borg/borgcron-local > /dev/null 2>&1" >> /var/spool/cron/crontabs/root
echo "" >> /var/spool/cron/crontabs/root
crontab /var/spool/cron/crontabs/root

#Parametro zabbix
if [ -f "/etc/zabbix/zabbix_agentd.conf" ]; then
    echo "Configurando zabbix"
    echo "UserParameter=borg.status.local, cat /etc/lunix/borg_status-local" >> /etc/zabbix/zabbix_agentd.conf
    echo "UserParameter=borg.status.lunix, cat /etc/lunix/borg_status-lunix" >> /etc/zabbix/zabbix_agentd.conf
    systemctl restart zabbix-agent.service
fi

#Seteamos valores iniciales
echo "1" > /etc/lunix/borg_status-lunix
echo "0" > /etc/lunix/borg_status-local

echo "Instalacion finalizada"