sudo git clone https://github.com/malavolti/HOWTO-Install-and-Configure-Shibboleth-Identity-Provider.git /usr/local/src/HOWTO-Shib-IdP &&

sudo apt update &&
sudo apt install vim default-jdk ca-certificates openssl tomcat8 apache2 ntp

sudo cp configs/hosts /etc/hosts
sudo cp configs/environment /etc/environment

sudo mkdir /root/certficates
sudo cp configs/idp-cert-server.crt /root/certficates/idp-cert-server.crt
sudo cp configs/idpkey-server.key /root/certficates/idpkey-server.crt
