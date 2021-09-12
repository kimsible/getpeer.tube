# Tests Guide

Clone the repository

```shell
git clone git@github.com:kimsible/getpeer.tube.git
cd getpeer.tube
```

Test locally install script

```shell
sudo sh script/index.sh
```

Test locally CLI
```shell
sh cli/peertube show-admin
sh cli/peertube show-dkim
sh cli/peertube upgrade
...
```

Certificate
During testing, the certificate will obviously fail if you don't have the domain name configuered with your IP, so use a `.local` domain **to not fetch letsencrypt servers**.
```shell
Requesting a certificate for peertube.local
An unexpected error occurred:
The server will not issue certificates for the identifier :: Error creating new order :: Cannot issue for "peertube.local": Domain name does not end with a valid public suffix (TLD)
Ask for help or search for solutions at https://community.letsencrypt.org. See the logfile /var/log/letsencrypt/letsencrypt.log or re-run Certbot with -v for more details.
```

Clean / uninstall
```shell
sh test/clean.sh
```

Test a specific branch environment

```shell
export GIT_BRANCH=develop
curl https://raw.githubusercontent.com/kimsible/getpeer.tube/develop/script/index.sh -o getpt-develop.sh
sudo sh getpt-develop.sh
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

