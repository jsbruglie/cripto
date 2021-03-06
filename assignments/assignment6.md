## Assignment 6 - Public Key Cryptography

- [1. Introduction](#1-introduction)
- [2. Setup](#2-setup)
- [3. HTTPS Secure Connections](#3-https-secure-connections)
  * [3.1 Creating a certification entity](#31-creating-a-certification-entity)
  * [3.2 Creating a certificate for the web server](#32-creating-a-certificate-for-the-web-server)
  * [3.3 Configuring Apache](#33-configuring-apache)
  * [3.4 Configuration of authentication with user / password](#34-configuration-of-authentication-with-user--password)
  * [3.5 Creating the client certificate](#35-creating-the-client-certificate)
  * [3.6 Importing the client and CA certificates into the browser](#36-importing-the-client-and-ca-certificates-into-the-browser)
  * [3.7 Apache configuration to accept authentication with certificates](#37-apache-configuration-to-accept-authentication-with-certificates)
  * [3.8 Apache configuration to accept authentication with certificates and passwords](#38-apache-configuration-to-accept-authentication-with-certificates-and-passwords)

### 1. Introduction

A certification authority (CA) is an entity that issues digital certificates, which validate the ownership of a public key using a given name.
This allows others to rely on these signatures to identify entities in communications.
Essentially it tackles the man-in-the-middle attack.
The CA acts as a trusted third party, that allows the authentication of the involved agents.

### 2. Setup

We will use the network described in Assignment 4, except machine 4 will not be needed.
The remaining 3 machines wil each play one of the following roles
- Web client - machine 1
- Web server - machine 2
- Certification authority - machine 3

### 3. HTTPS Secure Connections

HTTPS builds upon the specification of HTTP to add secure communication.
In HTTPS the communication protocol is encrytped using Transport Layer Security (TLS) or its predecessor Secure Sockets Layer (SSL).
It provides a way to authenticate the accessed website and ensures data privacy and integrity, through means of cryptography.

#### 3.1 Creating a certification entity

On machine 3 run 

```
sudo -i
mkdir /root/CA
chmod 0770 /root/CA
cd /root/CA
```

Public key (or asymmetrical) criptography relies on the use of a pair of public and private keys.
It simultaneously  accomplishes authentication and encryption:
    - The public key is used to verify the identity of the server (using a CA).
    - Anyone can encrypt messages with the public key, but only the receiver can decode them using the private key.

Generate a key pair for 2048-bit RSA cipher algorithm with the symmetric cipher algorithm 3DES (Triple DES) and a user-provided password (`inseguro`).
This will be the public and private key for the certification authority.

```
openssl genrsa -des3 -out my-ca.key 2048
```

After the keys have been generated it is necessary to sign the public key with the CA's private key.
This is a root-certificate (i.e. self-signed): the private signature key is the public key pair to be signed.
A self-signed certificate is similar to a certificate signing request (CSR), which is a solicitaion of a digital identity certificate from a certificate authority.
For this reason we use the same `req` command.
However, the `x509` utility is used to generate the certificate itself.

```
openssl req -new -x509 -days 3650 -key my-ca.key -out my-ca.crt
# Enter previously chosen passphrase
Country Name (2 letter code) [AU]: PT
State or Province Name (full name) [Some-State]: Lisbon
Locality Name (eg, city) []: Lisbon
Organization Name (eg, company) [Internet Widgits Pty Ltd]: CSC-9
Organizational Unit Name (eg, section) []: CA-9
Common Name (e.g. server FQDN or YOUR name) []: CA9
Email Address []: email@address.pt
```
To view the contents of your CA certificate you can run

```
openssl x509 -in my-ca.crt -text 2>&1 | less
```

2>&1 merges `stderr (2)` with `stdout (1)`, thus surpressing possible invalid permission errors.

### 3.2 Creating a certificate for the web server

On machine 2 run

```
cd ~/csc-course/assignment6
openssl genrsa -out csc-9-server.pem 1024
```

The latter command generates a key-pair for the 1024-bit RSA cypher.
At this point we have already encountered .key, .crt and .pem files.
For a decent clarification on the differences between them check [OpenSSL generated key formats].

The generated keys need to be signed.
For this reason generate a certificate request with

```
openssl req -new -key csc-9-server.pem -out csc-9-server.csr
Country Name (2 letter code) [AU]: PT
State or Province Name (full name) [Some-State]: Lisbon
Locality Name (eg, city) []: Lisbon
Organization Name (eg, company) [Internet Widgits Pty Ltd]: CSC-9
Organizational Unit Name (eg, section) []: Web server
Common Name (e.g. server FQDN or YOUR name) []: 192.168.1.2
Email Address []: email@address.pt
```

Notice that the common name is 192.168.1.2, which is the IP address that will be visible to our client in machine 1.

You will be prompted to generate an extra challenge password.
This challenge requested as part of the CSR generation is not the same thing as a passphrase used to encrypt the secret key.
The "challenge password" is essentially a shared-secret nonce between you and the CA, embedded in the CSR, which the issuer may use to authenticate you should that ever be needed.
You can disregard this step as well as the optional company name.

The certificate request file has to be sent over to machine 3.
You can pull the file from machine 3 by doing

```
cd /root/CA
scp user@machine2:csc-course/assignment6/csc-9-server.csr .
```

This time, we specify the IP to be 192.168.3.1 or refer to machine 2 my its host name.
Use the certificate from our CA to sign the web server certificate

```
sudo openssl x509 -req -in csc-9-server.csr -out csc-9-server.crt -sha1 -CA my-ca.crt -CAkey my-ca.key -CAcreateserial -days 3650
# Enter previously chosen passphrase
```

Make all certificates accessible to non-root users with

```
sudo chmod 444 *.crt
```

The issued can certificate can be viewed using the same command

```
openssl x509 -in csc-9-server.crt -text -noout 2>&1 | less
```

The `noout` flag  prevents output of the encoded version of the request.

### 3.3 Configuring Apache

Now we will install the private key, server certificate and the certificate from your CA.

In machine 2 run

```
cd ~/csc-course/assignment6
scp user@machine3:/root/CA/csc-9-server.crt .
scp user@machine3:/root/CA/my-ca.crt .
scp user@machine3:/root/CA/my-ca.key .
sudo chmod 0400 *.key
```

Should scp return a permission error, just copy the files elsewhere in machine 3 (for instance Desktop), and then use scp on machine 2 accordingly.
Then, edit the Apache WebServer configuration file with your favourite text editor (<s>`vim`</s> Sublime Text).

```
gksudo subl /etc/apache2/sites-available/default-ssl.conf
```

Change the respective fields to match

```
# Server certificate
SSLCertificateFile /home/user/csc-course/assignment6/csc-9-server.crt

# Server private key
SSLCertificateKeyFile /home/user/csc-course/assignment6/csc-9-server.pem

# Server certificate chain
SSLCertificateChainFile /home/user/csc-course/assignment6/my-ca.crt

# CA
SSLCACertificateFile /home/user/csc-course/assignment6/my-ca.crt
```

(I wouldn't bother closing this file as you still need to edit it a few more times.)
Create the directory for the protected content

```
sudo mkdir /var/www/SSL
sudo chmod 0775 /var/www/SSL
cd /var/www/SSL
```

Create a default index.html page with the content in [index1] or simply copy it

```
sudo cp ~/csc-course/assignment6/index1.html index.html
```

Create three other directories inside `www/SSL` and copy the respective index2 through 4 html files with

```
sudo mkdir Passneeded
sudo cp ~/csc-course/assignment6/index2.html Passneeded/index.html
sudo mkdir Certneeded
sudo cp ~/csc-course/assignment6/index3.html Certneeded/index.html
sudo mkdir PassAndCert
sudo cp ~/csc-course/assignment6/index4.html PassAndCert/index.html
```

Restart the web server with

```
sudo a2ensite default-ssl
sudo systemctl reload apache2
sudo service apache2 restart
```

`a2ensite` is a service to enable an apache2 site. `a2dissite` disables an apache2 site.

Finally check that Apache is listening on ports 80 and 443 with

```
sudo netstat -tulpn
```

The output should ìnclude something that resembles

```
tcp6       0      0 :::443                  :::*                    LISTEN      5142/apache2
tcp6       0      0 :::80                   :::*                    LISTEN      5142/apache2
```

If not, there is a good chance you messed something up, and nothing from this point on will work.
Be advised :) .

### 3.4 Configuration of authentication with user / password

Still in machine 2 create the directory for the password file

```
sudo mkdir /etc/apache2/www
```

Create several users with access to protected pages

```
sudo htpasswd -c -m /etc/apache2/www/.htpasswd User1
# Select new password (e.g. inseguro)

# ...
# htpasswd -c -m /etc/apache2/www/.htpasswd UserN
```

As per the [Apache docs] `htpasswd` is used to create and update the flat-files used to store usernames and password for basic authentication of HTTP users.
The -c flag creates the passwd file whereas -m specifies MD5 encryption for the passwords.

Configure the web server to protect the password directory

```
sudo chown www-data.www-data /etc/apache2/www/.htpasswd
sudo chmod 0460 /etc/apache2/www/.htpasswd
```

Edit the /etc/apache2/sites-available/default-ssl.conf and append

```
<Directory "/var/www/SSL/Passneeded">
    AuthType Basic
    AuthName "Username and Password Required"
    AuthUserFile /etc/apache2/www/.htpasswd
    Require valid-user
</Directory>
```

Restart the Apache server with

```
sudo service apache2 restart
```

### 3.5 Creating the client certificate

Go to machine 3 and generate a key pair for the client.
Notice that in this case the user is not required to generate a request.
The user just receives the certificaet and key in a single packet.

```
sudo -i
cd /root/CA
openssl genrsa -des3 -out client-cert.key 1024
# Enter pass phrase for client-cert and confirm (e.g. inseguro)
openssl req -new -key client-cert.key -out client-cert.csr
# Enter entity details (Country, City, etc...)
openssl x509 -req -in client-cert.csr -out client-cert.crt -sha1 -CA my-ca.crt -CAkey my-ca.key -CAcreateserial -days 3650
# Enter passphrase for my-ca.key

openssl pkcs12 -export -in client-cert.crt -inkey client-cert.key -name "User Cert" -out client-cert.p12
# Enter password for client-cert.key
# Enter export password and confirm
openssl pkcs12 -in client-cert.p12 -clcerts -nokeys -info
```

The last two commands mention PKCS#12 which is one of the family of standards known as Publick-Key Criptography Standards (PKCS).
Essentially we are converting a PEM certificate file and a private key to PKCS#12 denoted by the `.p12` extension.
Finally make the bundle accessible to other users with

```
chmod 444 client-cert.p12
```

### 3.6 Importing the client and CA certificates into the browser

Let us start with the server in machine 2.
Import the CA certificate and the bundle with certificate and private key of the client

```
sudo scp user@machine3:/root/CA/my-ca.crt  /var/www
sudo scp user@machine3:/root/CA/client-cert.p12  /var/www
```

(Again I had a permission error, so first copied the files to desktop in machine 3.)
Now, on machine 1 open the browser and navigate to `https://192.168.1.2/my-ca.crt`.
When prompted, choose to install the certificate.
When asked where to place the certifcate choose **trusted root certificate** (or just check all the boxes?).

Then, navigate to `https://192.168.1.2/client-cert.p12`
Download the file.
You should then import the certificate using your web browser.
For Mozilla Firefox go to `Preferences > Advanced > Certificates > View Certificates > Your Certificates` and import the downloaded client-cert.p12 file.

### 3.7 Apache configuration to accept authentication with certificates

In machine 2 edit /etc/apache2/sites-available/default-ssl.conf once more to append

```
<Directory "/var/www/SSL/Certneeded">
    SSLVerifyClient require
    SSLVerifyDepth 1
</Directory>
```

Restart the web server with `service apache2 restart` and test in machine 1 by navigating in the browser to `https://192.168.1.2/Certneeded`.
There should be a prompt confirming the use of the client certificate.
Accept and verify that you can correctly acces the protected web page.

### 3.8 Apache configuration to accept authentication with certificates and passwords

Finally, edit the default-ssl and combine the password and certificate authentication by adding

```
<Directory "/var/www/SSL/PassAndCert">
    SSLVerifyClient require
    SSLVerifyDepth 1
    AuthType Basic
    AuthName "Username and Password Required"
    AuthUserFile /etc/apache2/www/.htpasswd
    Require valid-user
</Directory>
```

Restart the Apache server and witness your amazing secure server in action by navigating to `https://192.168.1.2/SSL/PassAndCert/` in machine 1.

[Apache docs]: https://httpd.apache.org/docs/2.4/programs/htpasswd.html
[index1]: assignment6/index1.html
[OpenSSL generated key formats]: https://serverfault.com/questions/9708/what-is-a-pem-file-and-how-does-it-differ-from-other-openssl-generated-key-file