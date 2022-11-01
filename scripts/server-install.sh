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
echo "Instalando borgbackup"
if  [ "$CURL" ]; then
    curl --insecure -sL https://github.com/borgbackup/borg/releases/download/1.2.2/borg-linux64 -o /usr/local/bin/borg
else
    wget --no-check-certificate -q https://github.com/borgbackup/borg/releases/download/1.2.2/borg-linux64 -O /usr/local/bin/borg
fi
chown root:root /usr/local/bin/borg
chmod 755 /usr/local/bin/borg

#Descargar borg_config y borgcron.conf.template (en nuestro storage se edito borgcron.conf.template LOCAL => LUNIX)
echo "Instalando script de Lunix: borg_config"
mkdir -p /etc/lunix/borg/client/.ssh
if  [ "$CURL" ]; then
    curl --insecure -sL https://raw.githubusercontent.com/avillalba96/borg_config/master/borg_config -o /usr/local/sbin/borg_config
    curl --insecure -sL https://raw.githubusercontent.com/avillalba96/borg_config/master/borgcron.conf.template -o /etc/lunix/borg/client/borgcron.conf.template
else
    wget --no-check-certificate -q https://raw.githubusercontent.com/avillalba96/borg_config/master/borg_config -O /usr/local/sbin/borg_config
    wget --no-check-certificate -q https://raw.githubusercontent.com/avillalba96/borg_config/master/borgcron.conf.template -O /etc/lunix/borg/client/borgcron.conf.template
fi
chmod +x /usr/local/sbin/borg_config
chmod 600 -R /etc/lunix/borg

#Editamos el EMAIL en borgcron.conf.template
echo "Colocar el EMAIL que se usara para enviar las alertas de fallas:"
read EMAIL
sed -i "s/ing@example.com/$EMAIL/g" /etc/lunix/borg/client/borgcron.conf.template
echo ""

#Descargar borg_tools y borgcron-prune
if  [ "$CURL" ]; then
    curl --insecure -sL https://raw.githubusercontent.com/avillalba96/borg_config/master/borg_tools_storage -o /usr/local/sbin/borg_tools_storage
    curl --insecure -sL https://raw.githubusercontent.com/avillalba96/borg_config/master/borgcron-prune-server -o /etc/lunix/borg/borgcron-prune
else
    wget --no-check-certificate -q https://raw.githubusercontent.com/avillalba96/borg_config/master/borg_tools_storage -O /usr/local/sbin/borg_tools_storage
    wget --no-check-certificate -q https://raw.githubusercontent.com/avillalba96/borg_config/master/borgcron-prune-server -O /etc/lunix/borg/borgcron-prune
fi
chmod +x /usr/local/sbin/borg_tools_storage
chmod +x /etc/lunix/borg/borgcron-prune
echo "Instalando script de Lunix: borgcron logrotate"
if  [ "$CURL" ]; then
    curl --insecure -sL https://raw.githubusercontent.com/avillalba96/borg_config/master/borg_logrotate -o /etc/logrotate.d/borg
else
    wget --no-check-certificate -q https://raw.githubusercontent.com/avillalba96/borg_config/master/borg_logrotate -O /etc/logrotate.d/borg
fi

#Generar carpeta para repositorio
if [ ! -d /u/borgbackup/ ]; then
    mkdir -p /u/borgbackup/;
fi

#Carpeta para logs
mkdir /var/log/borg
#Agregar usuario y home de borg
echo "Generando usuario y home para borg"
useradd borg -s /bin/sh -m
if [ ! -d /home/borg/.ssh ]; then mkdir /home/borg/.ssh; fi
chown borg.borg -R /home/borg/.ssh
chown borg.borg -R /u/borgbackup/

#Cron
echo "Agregando cron"
touch /var/spool/cron/crontabs/root
echo "" >> /var/spool/cron/crontabs/root
echo "#Borg Prune dos veces al mes" >> /var/spool/cron/crontabs/root
echo "00 18 1,16 * * /etc/lunix/borg/borgcron-prune > /dev/null 2>&1" >> /var/spool/cron/crontabs/root

#Parametro zabbix
if [ -f "/etc/zabbix/zabbix_agentd.conf" ]; then
    echo "UserParameter=borg_prune.status, cat /etc/lunix/borg_prune_status" >> /etc/zabbix/zabbix_agentd.conf
    systemctl restart zabbix-agent.service
fi

echo "Instalacion finalizada"
echo "Configurar las variables SERVER y PORT en /usr/local/sbin/borg_config"
