# How « Install PeerTube » works

⚠️ **DISCLAIMER ON UPGRADING**<br>
This script is also able to upgrade the stack but in production:

✋  **DO NOT USE THIS SCRIPT** if you've **customized nginx or docker-compose** configuration files.<br>
  💡 Instead prefer editing any file one by one and use the CLI.<br>
  💡 Before any upgrade don't forget to backup your peertube docker stack.

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

## Use cases

### Basic usage with cURL or Wget

```shell
curl https://getpeer.tube | sh
```
```shell
wget https://getpeer.tube -O - | sh
```


### Advanced usage with env vars

An upgrade will **auto-fill** environment variables `MY_EMAIL_ADDRESS` and `MY_DOMAIN` with existing ones. But when install you may want define them:

```shell
MY_EMAIL_ADDRESS=me@domain.tld MY_DOMAIN=domain.tld curl https://getpeer.tube | sh
```
```shell
MY_EMAIL_ADDRESS=me@domain.tld MY_DOMAIN=domain.tld wget https://getpeer.tube -O - | sh
```

You can also download and run [the script](https://raw.github.com/kimsible/install-peertube/master/install.sh) manually.



## Extended CLI

### Official Server Tools

You can use all the [official server tools commands](https://docs.joinpeertube.org/maintain-tools?id=server-tools):

```bash
$ peertube parse-log
$ peertube prune-storage
$ peertube update-host
$ peertube reset-password -- -u target_username
$ peertube plugin:install -- --npm-name peertube-plugin-myplugin
...
```

### Backup and Restore

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

### Migration server to server

On the old server :

```bash
$ peertube postgres:dump /var/peertube/docker-volume/db.tar
$ peertube down
$ rsync -av --exclude docker-volume/db /var/peertube/ username@new-server:/var/peertube/
```

**WARNING**: this command could fail with `docker-volume/opendkim/keys/peertube.*` if you do not have a root access on the old server, in this case, don't worry, you just need to copy them manually. =)

On the new server :
```bash
$ peertube postgres:up
$ peertube postgres:restore /var/peertube/docker-volume/db.tar
$ systemctl start peertube
```

### Command List

Simply:
```bash
$ peertube
```

Or see https://github.com/kimsible/install-peertube/master/cli/peertube.

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
