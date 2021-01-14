echo ""
read -r -p 'Enter Domain to deploy =  ' longdomain
read -r -p 'Enter password administrator of Domain =  ' password

# Global conf
#longdomain=lan.ecogo.com.ar
realm=${longdomain^^}
shortdomain=`echo $realm | awk -F \. '{ print $2 }'`
#password=
ip_address=`hostname -I | awk '{ print $1 }'`
ip_gateway=`ip r | grep default | awk '{ print $3 }'`
timezone=America/Argentina/Buenos_Aires

# Generic Conf
TIMESTAMP=`/bin/date +%d-%m-%Y_%T`
linuxdistribution=`awk '{ print $1 }' /etc/issue`

echo "
check information to proceed to install Samba DC:

realm    = $realm
domain   = $shortdomain
Local IP = $ip_address
Linuxdistribution = $linuxdistribution

"


while true; do
        read -p "is it correct? do you wish to continue? (y/n)" yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

#apt update && apt dist-upgrade -y &&

#if [ "$?" != "0" ] ; then
#
#        EXIT_STATUS=1
#        echo "${TIMESTAMP} $0: Se produjo un error al actualizar"
#        exit
#        else
#fi

timedatectl set-timezone $timezone &&

DEBIAN_FRONTEND=noninteractive apt install samba samba-common smbclient dnsutils ldap-utils ldb-tools winbind acl krb5-user -yq &&

if [ "$?" != "0" ] ; then

        EXIT_STATUS=1
        echo "${TIMESTAMP} $0: Se produjo un error al instalar los paquetes necesarios"
        exit
fi

mv /etc/samba/smb.conf /etc/samba/smb.conf.original &&

Ubuntu=Ubuntu

#if [ "$linuxdistribution" = "$Ubuntu" ]; then
    systemctl stop systemd-resolved && systemctl disable systemd-resolved &&
#else
#    echo "continue"
#fi

if [ "$?" != "0" ]
        then
        EXIT_STATUS=1
        echo "${TIMESTAMP} $0: Se produjo un error al stopear systemd"
        exit
      else
        echo "continue"
fi



samba-tool domain provision --server-role=dc --use-rfc2307 --dns-backend=SAMBA_INTERNAL --realm=$realm --domain=$shortdomain --adminpass=$password &&

if [ "$?" != "0" ] ; then

        EXIT_STATUS=1
        echo "${TIMESTAMP} $0: Deploy domain privision error"
        exit
      else
        echo "continue"
fi


cp /var/lib/samba/private/krb5.conf /etc/krb5.conf

systemctl stop smbd &&
systemctl disable smbd &&
systemctl stop nmbd &&
systemctl disable nmbd &&
systemctl stop winbind &&
systemctl disable winbind &&
systemctl unmask samba-ad-dc &&
systemctl start samba-ad-dc &&
systemctl enable samba-ad-dc &&

#echo "el servidor se va a reiniciar"
#reboot

smbclient -L localhost -U%


if [ "$?" != "0" ] ; then
        EXIT_STATUS=1
        echo "${TIMESTAMP} $0: error accediendo carpetas, probar reiniciar y probar: smbclient -L localhost -U%
        revisar: servicio samba-ad-dc si esta activo, firewall y DNS externo"
        else
        echo "
        ---------------------------------------
        Felicitaciones: El deploy fue correcto
        --------------------------------------"
fi

echo "
BONUS
Comando para correr en Mikrotik para un DNS Conditional Forwarder:

/ip firewall layer7-protocol add name=$longdomain regexp=.$longdomain
/ip firewall mangle add chain=prerouting dst-address=$ip_gateway layer7-protocol=$longdomain action=mark-connection new-connection-mark=$longdomain-forward protocol=tcp dst-port=53
/ip firewall mangle add chain=prerouting dst-address=$ip_gateway layer7-protocol=$longdomain action=mark-connection new-connection-mark=$longdomain-forward protocol=udp dst-port=53
/ip firewall nat add action=dst-nat chain=dstnat connection-mark=$longdomain-forward to-addresses=$ip_address
/ip firewall nat add action=masquerade chain=srcnat connection-mark=$longdomain-forward"
