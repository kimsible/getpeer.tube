# How getpeer.tube works

## Steps

- Check if the script is running as root
- Check if the host works with systemd
- Check if cURL is installed
- Check if **Docker >= v17.06** is installed
- Install or upgrade Compose binary from GitHub Releases
- Create or upgrade CLI

The next steps are done only if there is not any PeerTube docker stack already installed:

- Ask domain and email if not defined in environment variables
- Create non-root system user owner of working directory
- Create working directory `/var/peertube`
- Get latest official compose setup of PeerTube stack from GitHub Raw
  - Generate PostgreSQL credentials
  - Use defined `MY_EMAIL_ADDRESS` and `MY_DOMAIN` and wait for editing updated `.env`
- Create `peertube.service`
- Pull latest images
- Run `peertube.service`
- Up the stack

## Use cases

### Basic usage with cURL

```shell
curl https://getpeer.tube | sh
```

### Advanced usage with env vars

You may want to **auto-fill** environment variables `MY_EMAIL_ADDRESS` and `MY_DOMAIN`:

Step by step:
```shell
export MY_EMAIL_ADDRESS=me@domain.tld
export MY_DOMAIN=domain.tld
curl https://getpeer.tube -o getpeertube.sh
sh getpeertube.sh
```

By one command:
```shell
MY_EMAIL_ADDRESS=me@domain.tld MY_DOMAIN=domain.tld curl https://getpeer.tube | sh
```

You can also download and run [the script](https://raw.github.com/kimsible/getpeer.tube/master/script/index.sh) manually.


## Extended CLI

### Automatic upgrade

⚠️ **Before any upgrade**<br>
💡 Don't forget to [backup your peertube docker stack](https://github.com/kimsible/backup-peertube).<br>
💡 Edit any configuration file one by one if required by the release.<br>
💡 Check breaking changes here: https://github.com/Chocobozzz/PeerTube/releases

```bash
$ peertube upgrade
```

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

If you've dumped the database you don't need to copy the db files in the mounted volume :
```bash
$ rm -r /var/peertube/docker-volume/db
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
$ peertube # Will display command list
```

Or see https://github.com/kimsible/getpeer.tube/blob/master/cli/peertube.

### Uninstall

Want to uninstall the PeerTube stack and / or the CLI ?

```shell
systemctl disable peertube # disabled peertube service
rm /etc/systemd/system/peertube.service # delete peertube service

cd /var/peertube
docker-compose down -v --remove-orphans # down all containers

docker rmi $(docker images -a -q) # remove all cached images
docker volume rm $(docker volume ls -q) # remove all cached volumes

docker network prune # remove all unsued networks

rm /usr/sbin/peertube # remove CLI

rm -r /var/peertube #remove peertube stack
```

## Development

See https://github.com/kimsible/getpeer.tube/blob/master/test/README.md
