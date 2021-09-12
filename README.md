# getpeer.tube

> **Installing** of [PeerTube](https://joinpeertube.org) docker stack by one SHELL command

```shell
curl https://getpeer.tube | sh
```

This script builds a PeerTube docker stack for production. It runs on most **x86-64 linux distributions** and brings:

- 📖 [Official docker-compose production setup](https://docs.joinpeertube.org/install-docker)
- 🧰 [Extended PeerTube CLI](https://github.com/kimsible/getpeer.tube/blob/master/DOCUMENTATION.md#extended-cli)


## Server requirements

- x86-64 Linux Distribution updated
- SSH access **as root** or sudoer user with `sudo` prefix
- Access on **port 25 (smtp)**, **port 80 (http)**, **port 443 (https)** and **port 1935 (rtmp)**
- A Domain Name pointing to this server
- **[Docker](https://docs.docker.com/install/) >= v17.06**

## Upgrade an older version of the CLI

You simply need to re-run the main command, the script will automatically detect the docker stack already installed to only upgrade Docker Compose and CLI.

```shell
$ curl https://getpeer.tube | sh

Prerequisites \
 root OK
 systemd OK
 curl OK
 docker OK

Docker stack already exists in /var/peertube

Upgrading Compose and CLI only \
Checking latest release of Compose     ... done
Upgrading Docker Compose               ... done
 → from 1.28.3 to 1.29.2
Installing CLI into /usr/sbin/peertube ... done

Docker Compose and the CLI are now successfully upgraded!

```

## Documentation

See the [Documentation](https://github.com/kimsible/getpeer.tube/blob/master/DOCUMENTATION.md).

## FAQ

What does the script do?
- Installing or upgrading docker-compose
- Building stack tree in /var/peertube _with official config files_
- Creating systemd service
- Generating first SSL certificate
- Pulling images
- Starting the stack
- Exposing CLI server tools and more
- Displaying DKIM TXT Record via CLI
- Displaying admin-credentials via CLI
- Upgrading stack via CLI _after manual config merging/editing_


What does the script **not** do?
- Installing/Upgrading operating system
- Installing/Upgrading docker
- Configuring ports in your server firewall
- Configuring server IP in your DNS Server Zone
- Configuring postfix DKIM in your DNS Server Zone
- **Merging new releases changes of nginx, compose and .env files**
- **Backup or restore stack**
