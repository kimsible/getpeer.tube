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
 → upgrade Compose and CLI only
Checking latest release of Compose     ... done
Installing Docker Compose 1.29.2       ... done
 → into /usr/local/bin/docker-compose
Installing CLI into /usr/sbin/peertube ... done

Docker Compose and the CLI are now successfully upgraded!

```



## Documentation

See the [Documentation](https://github.com/kimsible/getpeer.tube/blob/master/DOCUMENTATION.md).
