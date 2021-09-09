# Install PeerTube `$_`

> **Installing** of [PeerTube](https://joinpeertube.org) docker stack by one SHELL command

This script builds a PeerTube docker stack for production. It runs on most **x86-64 linux distributions** and brings:

- 📖 [Official docker-compose production setup](https://docs.joinpeertube.org/#/install-docker)
- 🧰 [Extended PeerTube CLI](https://github.com/kimsible/install-peertube/master/DOCUMENTATION.md#extended-cli)


## Server requirements

- x86-64 Linux Distribution updated
- SSH access **as root** or sudoer user with `sudo` prefix
- Access on **port 25 (smtp)**, **port 80 (http)**, **port 443 (https)** and **port 1935 (rtmp)**
- A Domain Name pointing to this server
- **[Docker](https://docs.docker.com/install/) >= v17.06**

## Basic usage with **cURL** or **Wget**

```shell
sh -c "$(curl -fsSL https://raw.github.com/kimsible/install-peertube/master/install.sh)"
```
```shell
sh -c "$(wget https://raw.github.com/kimsible/install-peertube/master/install.sh -O -)"
```

## Documentation

See [Documentation Guide](https://github.com/kimsible/install-peertube/master/DOCUMENTATION.md).
