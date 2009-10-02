#/bin/dash

PEM=/etc/apache2/ssl/apache.pem
ALIAS=$(hostname -f)

echo 'generating a 2048 bit self-signed cert'  
mkdir -p /etc/apache2/ssl    
export RANDFILE=/dev/random         
openssl req -batch -subj "/CN=$ALIAS" -newkey rsa:2048 -new -x509 -nodes -out $PEM \
    -keyout $PEM
chmod 600 $PEM
ln -sf $PEM /etc/apache2/ssl/`/usr/bin/openssl x509 -noout -hash < $PEM`.0

/etc/init.d/apache2 restart