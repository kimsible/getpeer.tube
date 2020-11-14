# Install PeerTube

**Installing** and **upgrading** of the [PeerTube](https://joinpeertube.org) stack with one SHELL command.

This script is based on [the official docker production setup](https://docs.joinpeertube.org/#/install-docker) and runs on most x86-64 linux distributions.

### Server requirements

- x86-64 Linux Distribution updated
- SSH access **as root** or sudoer user with `sudo` prefix
- Access on **port 25 (smtp)**, **port 80 (http)** and **port 443 (https)**
- A Domain Name pointing to this server
- **[Docker](https://docs.docker.com/install/) >= v17.06**

## Usage

Basic usage with **cURL** or **Wget**.
```shell
sh -c "$(curl -fsSL https://raw.github.com/kimsible/install-peertube/master/install.sh)"
```
```shell
sh -c "$(wget https://raw.github.com/kimsible/install-peertube/master/install.sh -O -)"
```

An upgrade will **auto-fill** environment variables `MY_EMAIL_ADDRESS` and `MY_DOMAIN`, when install you'll need to define them :

```shell
MY_EMAIL_ADDRESS=me@domain.tld MY_DOMAIN=domain.tld \
sh -c "$(curl -fsSL https://raw.github.com/kimsible/install-peertube/master/install.sh)"
```
```shell
MY_EMAIL_ADDRESS=me@domain.tld MY_DOMAIN=domain.tld \
sh -c "$(wget https://raw.github.com/kimsible/install-peertube/master/install.sh -O -)"
```

You can also download and run [the script](https://raw.github.com/kimsible/install-peertube/master/install.sh) manually.

## Steps

- Check if the script is running as root
- Check if the host works with systemd
- Check if cURL or Wget are installed
- Check if **Docker >= v17.06** is installed
- Stop existing `peertube.service`
- Install or upgrade Compose binary from GitHub Releases
- Create working directory `/var/peertube`
- Create non-root system user owner of working directory
- Get latest official compose setup of PeerTube stack from GitHub Raw
  - Generate or use existing PostgreSQL credentials
  - Use defined `MY_EMAIL_ADDRESS` and `MY_DOMAIN` or wait for editing updated `.env`
- Create or update `peertube.service`
- Pull latest images
- Run `peertube.service`
- Display **PeerTube Admin Credentials** once server up or error logs
- Display **PeerTube DKIM DNS TXT Record** to configure into your Domain Name System zone

## Backup / Restore

For each backup you'll need to dump the PostreSQL database :

Before backup
```bash
$ peertube postgres:dump /var/peertube/docker-volume/db.tar
```

For each restoration you need to down all container with :

Before restoration
```bash
$ peertube down
```

After restoration
```bash
$ peertube postgres:restore /var/peertube/docker-volume/db.tar
$ peertube up
```


### Mirror Backup

Backup command

```bash
$ rsync -raP --exclude docker-volume/db /var/peertube/* username@remote-server:/path/to/peertube --delete
```

To include the backup command in a script without password prompt, you might use sshpass before :
```bash
$ sshpass -p yourpassword rsync -raP --exclude docker-volume/db /var/peertube/* username@remote-server:/path/to/peertube --delete
```

Basic Restore command only for missing files

```bash
$ rsync -raP username@remote-server:/pat/to/peertube /var --delete
```

Full Restore command

```bash
$ rsync -raP username@remote-server:/path/to/peertube /var --delete --ignore-times
```

For specific protocol without rsync or SSH support like FTP, you might use [rclone](https://rclone.org/ftp/).

### Daily Backup

- Edit crontab with `crontab -u root -e`
- Add this line to run it as docker user every day at 5:25am :

```bash
25 5  * * * /usr/bin/peertube-mirror
```

### Incremential Backup

## Migration server to server

On the old server :

```bash
$ peertube postgres:dump /var/peertube/docker-volume/db.tar
$ peertube down
$ rsync -raP --exclude docker-volume/db /var/peertube/* username@new-server:/var/peertube
```

On the new server :
```bash
$ peertube postgres:up
$ peertube postgres:restore
$ systemctl start peertube
```

## Development

Basic usage with **cURL** or **Wget**.
```shell
GIT_BRANCH=develop sh -c "$(curl -fsSL https://raw.github.com/kimsible/install-peertube/develop/install.sh)"
```
```shell
GIT_BRANCH=develop sh -c "$(wget https://raw.github.com/kimsible/install-peertube/develop/install.sh -O -)"
```

This error occurs if you have already installed peertube in another working directory.

```
ERROR: Pool overlaps with other one on this address space
```

To solve that issue you need to stop all old running containers and remove all unsused networks created by these old ones.
```shell
docker stop $(docker ps -a -q)
docker network prune
```

Magic command to reset all docker containers, images, volumes and networks.

```shell
docker stop $(docker ps -a -q) & wait; docker rm $(docker ps -a -q) & wait; docker rmi $(docker images -a -q); docker volume rm $(docker volume ls -q) & wait; docker network prune -f
```
