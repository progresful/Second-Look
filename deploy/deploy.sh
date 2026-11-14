#!/bin/sh
# Deploy the Second Look API to an Ubuntu + nginx server.
# Usage: deploy/deploy.sh user@host   (the user needs sudo; key login only)
set -eu
TARGET="$1"
KEY="${KEY:-$HOME/.ssh/secondlook_deploy}"
SSH="ssh -i $KEY -o IdentitiesOnly=yes"
cd "$(dirname "$0")/.."
rsync -az --delete -e "$SSH" --exclude .venv --exclude __pycache__ --exclude .env --exclude '*.log' api/ "$TARGET:/tmp/secondlook-api/"
scp -i "$KEY" -o IdentitiesOnly=yes api/.env "$TARGET:/tmp/secondlook.env"
scp -i "$KEY" -o IdentitiesOnly=yes deploy/secondlook.service deploy/secondlook.pgf.lv.nginx "$TARGET:/tmp/"
$SSH "$TARGET" 'set -eu
sudo id secondlook >/dev/null 2>&1 || sudo useradd --system --home /opt/secondlook --shell /usr/sbin/nologin secondlook
sudo mkdir -p /opt/secondlook/api
sudo rsync -a --delete --exclude .venv --exclude .env /tmp/secondlook-api/ /opt/secondlook/api/
sudo install -m 600 -o secondlook -g secondlook /tmp/secondlook.env /opt/secondlook/api/.env
rm -f /tmp/secondlook.env
command -v python3 >/dev/null && python3 -m venv --help >/dev/null 2>&1 || sudo apt-get install -y python3-venv
[ -x /opt/secondlook/api/.venv/bin/python ] || sudo python3 -m venv /opt/secondlook/api/.venv
sudo /opt/secondlook/api/.venv/bin/pip install -q -r /opt/secondlook/api/requirements.txt
sudo chown -R secondlook:secondlook /opt/secondlook
sudo install -m 644 /tmp/secondlook.service /etc/systemd/system/secondlook.service
sudo install -m 644 /tmp/secondlook.pgf.lv.nginx /etc/nginx/sites-available/secondlook.pgf.lv
sudo ln -sf /etc/nginx/sites-available/secondlook.pgf.lv /etc/nginx/sites-enabled/secondlook.pgf.lv
sudo systemctl daemon-reload
sudo systemctl enable --now secondlook
sudo systemctl restart secondlook
sudo nginx -t && sudo systemctl reload nginx
sleep 2; curl -s http://127.0.0.1:8770/health'
