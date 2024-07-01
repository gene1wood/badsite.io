Please note that this project is in beta, due to requirements to be completed by MozFest.

Visit [`badsite.io`](https://badsite.io/) for a list of test subdomains, including:

- [`no-csp-xss.badsite.io`](https://no-csp-xss.badsite.io)
- [`no-xfo.badsite.io`](https://no-xfo.badsite.io)
- [`observatory-a.badsite.io`](https://observatory-a.badsite.io)
- [`hsts.badsite.io`](https://hsts.badsite.io)

## Server Setup

Stock Ubuntu VM, DNS A records for `badsite.test.` and `*.badsite.test.` pointing to the VM.

### Testing and development

1. Follow the instructions to [install Docker.](https://www.docker.io/get-docker)

2. Clone into the badsite repo by running `git clone https://github.io/april/badsite.io && cd badsite.io`.
 
3. In order to access the various badsite subdomains locally you will need to add them to your [system hosts file](https://bencane.io/2013/10/29/managing-dns-locally-with-etchosts/). Run `make list-hosts` and copy and paste the output into `/etc/hosts`. 

4. Start Docker by running `make serve`.

5. You can now navigate to `badsite.test` in your browser, and you should see a certificate error.

6. The badsite root certificate is at `certs/sets/test/gen/crt/ca-root.crt`. In order to get the rest of the badsite subdomains working, you will need to add this to your machine's list of trusted certificates.
    - On `macOS`, drag `certs/sets/test/gen/crt/ca-root.crt` into the login section of the program Keychain Access. A BadSite Root Certificate Authority entry should appear in the list. Double-click on this entry and select "Use Custom Settings" from the drop-down menu next to "When using this certificate." Then select "Always Trust" from the drop-down menu next to "Secure Sockets Layer (SSL)." Close the window to save your changes.
    
      If you are already familiar with this process, you can instead run this command:

      ```
      security add-trusted-cert -r trustRoot -p ssl \
        -k "$HOME/Library/Keychains/login.keychain" certs/sets/test/gen/crt/ca-root.crt
      ```

7. In order to preserve the root certificate even after running `make clean`, run:

```
cd certs/sets/test
mkdir -p pregen/crt pregen/key
cp gen/crt/ca-root.crt pregen/crt/ca-root.crt
cp gen/key/ca-root.key pregen/key/ca-root.key
```

### Deploying with docker

1. Create DNS records in two different domains, for example badsite.security.allizom.org and badsite.infosec.mozilla.org
   that point to your server
2. Create DNS wildcard records for each domain as well (e.g. *.badsite.security.allizom.org)
3. Get docker
   ```shell
   wget -qO - https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
   apt-add-repository https://download.docker.com/linux/ubuntu
   apt install docker-ce make
   ```
4. Checkout the code
   ```shell
   git clone https://github.com/gene1wood/badsite.io.git && \
   cd badsite.io && \
   git checkout update_badsite
   ```
5. Initiate a certificate request
   ```shell
   certbot certonly --agree-tos --no-eff-email \
   -m user@example.com --manual --manual-public-ip-logging-ok \
   --preferred-challenges dns \
   -d 'badsite.security.allizom.org' \
   -d '*.badsite.security.allizom.org' \
   -d '*.badsite.infosec.mozilla.org'
   ```
6. Copy paste the public key that certbot outputs into Route53 or your DNS
7. Put the cert in the right location
   ```shell
   mkdir -p certs/sets/current/gen/chain certs/sets/current/gen/key
   cp -v /etc/letsencrypt/live/badsite.security.allizom.org/fullchain.pem certs/sets/current/gen/chain/wildcard-rsa2048.pem
   cp -v /etc/letsencrypt/live/badsite.security.allizom.org/privkey.pem certs/sets/current/gen/key/leaf-rsa2048.key
   ```
8. Build the docker image
   ```shell
   docker build --build-arg domain=badsite.security.allizom.org \
     --build-arg test_domain=badsite.security.allizom.org \
     --build-arg cross_origin_domain=badsite.infosec.mozilla.org \
     --build-arg cross_origin_test_domain=badsite.infosec.mozilla.org \
     -t badsite .
   ```
9. Get docker-compose
   ```shell
   curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   chmod +x /usr/local/bin/docker-compose
   ```
10. Create Docker Compose Systemd Service by creating a /etc/systemd/system/docker-compose@.service file with the contents
   ```text
   [Unit]
   Description=%i service with docker compose
   Requires=docker.service
   After=docker.service
   
   [Service]
   WorkingDirectory=/etc/docker/compose/%i
   Restart=always
   ExecStartPre=/usr/local/bin/docker-compose down --volumes
   ExecStartPre=/usr/local/bin/docker-compose rm -v --force
   ExecStartPre=-/bin/bash -c 'docker volume ls --quiet --filter "name=%i_" | xargs --no-run-if-empty docker volume rm'
   ExecStartPre=-/bin/bash -c 'docker network ls --quiet --filter "name=%i_" | xargs --no-run-if-empty docker network rm'
   ExecStartPre=-/bin/bash -c 'docker ps --all --quiet --filter "name=%i_*" | xargs --no-run-if-empty docker rm'
   ExecStart=/usr/local/bin/docker-compose up --no-color
   ExecStop=/usr/local/bin/docker-compose down --volumes
   
   [Install]
   WantedBy=multi-user.target
   ```
11. Create a service
   ```shell
   mkdir -p /etc/docker/compose/badsite/
   cp docker-compose.yml /etc/docker/compose/badsite/
   systemctl start docker-compose@badsite
   systemctl enable docker-compose@badsite
   ```

This process doesn't enable automatic certificate renewal as the DNS is managed outside of the instance. With this setup
you'll need to update DNS manually to renew the certificate which would look like

```shell
certbot certonly --agree-tos --no-eff-email -m user@example.com --manual --manual-public-ip-logging-ok --preferred-challenges dns -d 'badsite.security.allizom.org' -d '*.badsite.security.allizom.org' -d '*.badsite.infosec.mozilla.org'
cp -v /etc/letsencrypt/live/badsite.security.allizom.org/fullchain.pem /root/badsite.io/certs/sets/current/gen/chain/wildcard-rsa2048.pem
cp -v /etc/letsencrypt/live/badsite.security.allizom.org/privkey.pem /root/badsite.io/certs/sets/current/gen/key/leaf-rsa2048.key
docker build --build-arg domain=badsite.security.allizom.org   --build-arg test_domain=badsite.security.allizom.org   --build-arg cross_origin_domain=badsite.infosec.mozilla.org   --build-arg cross_origin_test_domain=badsite.infosec.mozilla.org   -t badsite /root/badsite.io
systemctl stop docker-compose@badsite
systemctl start docker-compose@badsite
```

## Acknowledgments

badsite.io is hosted on Mozilla infrastructure and co-maintained by:

- [April King](https://github.io/april), Mozilla Firefox
- [Lucas Garron](https://github.io/lgarron), Google Chrome

## Disclaimer

`badsite.io` is meant for *manual* testing of web security in clients and test tools.

Most subdomains are likely to have stable functionality, but anything *could* change without notice. If you would like a documented guarantee for a particular use case, please file an issue. (Alternatively, you could make a fork and host your own copy.)

badsite.io is not an official Mozilla or Google product. It is offered "AS-IS" and without any warranties.
