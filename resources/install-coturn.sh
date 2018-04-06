# From: https://github.com/matrix-org/synapse/blob/master/docs/turn-howto.rst

if [ -z "$1" ]; then
    echo 1>&2 "realm argument is missing."
    echo "Usage: bash $0 yourdomain.com"
    exit 2
fi

sudo apt install -y pwgen
sudo apt install -y coturn

REALM=$1
# TODO: Read from arguments
PORT=8443
TLS_PORT=5349

echo
echo "Enabling COTURN..."
sudo sed -i -e 's/#TURNSERVER_ENABLED=1/TURNSERVER_ENABLED=1/g' /etc/default/coturn
echo
echo '# Autogenerated config' | sudo tee --append /etc/turnserver.conf
echo 'fingerprint' | sudo tee --append /etc/turnserver.conf
echo 'lt-cred-mech' | sudo tee --append /etc/turnserver.conf
echo "listening-port=$PORT" | sudo tee --append /etc/turnserver.conf
echo "tls-listening-port=$TLS_PORT" | sudo tee --append /etc/turnserver.conf
echo 'use-auth-secret' | sudo tee --append /etc/turnserver.conf
SECRET=$(pwgen -s 64 1)
echo "static-auth-secret=[$SECRET]" | sudo tee --append /etc/turnserver.conf
echo "realm=$REALM" | sudo tee --append /etc/turnserver.conf
sudo mkdir /var/log/turnserver
echo 'log-file=/var/log/turnserver/turn.log' | sudo tee --append /etc/turnserver.conf
echo '# Security settings' | sudo tee --append /etc/turnserver.conf
echo 'no-tcp-relay' | sudo tee --append /etc/turnserver.conf
echo 'bps-capacity=0' | sudo tee --append /etc/turnserver.conf
echo 'stale-nonce' | sudo tee --append /etc/turnserver.conf
echo 'no-loopback-peers' | sudo tee --append /etc/turnserver.conf
echo 'no-multicast-peers' | sudo tee --append /etc/turnserver.conf
echo 'total-quota=256' | sudo tee --append /etc/turnserver.conf
echo 'denied-peer-ip=10.0.0.0-10.255.255.255 denied-peer-ip=192.168.0.0-192.168.255.255 denied-peer-ip=172.16.0.0-172.31.255.255' | sudo tee --append /etc/turnserver.conf
echo 'allowed-peer-ip=10.0.0.1' | sudo tee --append /etc/turnserver.conf
sudo ufw allow turnserver
echo
echo "Configuring Synapse to use local COTURN (this is needed for WebRTC behind NAT)..."
echo

# TODO: Port should be checked
sudo sed -i "s/turn_uris:[[:space:]]\[\]/turn_uris: \[\"turn:turn.$REALM:$PORT?transport=udp\"\]/g" /etc/matrix-synapse/homeserver.yaml
sudo sed -i "s/YOUR_SHARED_SECRET/$SECRET/g" /etc/matrix-synapse/homeserver.yaml
# turn_allow_guests: TRUE

echo -n "Start TURN/STUN service (y/n)? "
read answer
if echo "$answer" | grep -iq "^y" ;then
   sudo turnserver -c /etc/turnserver.conf --daemon -v
   sudo systemctl restart matrix-synapse
   echo
   echo "coturn service started..."
   echo "You need to set DNS record for turn.$REALM to point to this server."
fi
echo
echo "Your COTURN server shared secret (write it somewhere):"
echo $SECRET
echo