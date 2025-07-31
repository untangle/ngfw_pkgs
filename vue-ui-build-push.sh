#!/bin/bash
set -euo pipefail

echo ">>> Step 1: Move to source directory"
cd untangle-vue-ui/source

echo ">>> Step 2: Remove yarn.lock if it exists"
[ -f yarn.lock ] && rm yarn.lock

# echo ">>> Step 3: Fix permissions and run yarn clean, install, and upgrade"
# # Make sure current user owns the directory (recursive)
# sudo chown -R "$(whoami)":"$(whoami)" .

# # # echo ">>> Step 3: Run yarn clean, install, and upgrade"
# yarn clean
# yarn install
# yarn upgrade

echo ">>> Step 4: Start ssh-agent"
eval "$(ssh-agent -s)"

cd ../..

echo ">>> Step 5: Add SSH key"
ssh-add ~/.ssh/id_ed25519

echo ">>> Step 6: Remove existing .deb files"
rm -f ./*.deb

echo ">>> Step 7: Run docker compose build"
PACKAGE=untangle-vue-ui FORCE=1 VERBOSE=1 UPLOAD=local docker compose -f docker-compose-ngfw-ui-build.yml run build

echo ">>> Step 8: Verify .deb package was created"
DEB_FILE=$(ls untangle-vue-ui_17.4.0*.deb 2>/dev/null || true)

if [ -z "$DEB_FILE" ]; then
    echo "ERROR: No .deb file was generated."
    exit 1
fi

echo ">>> .deb package generated: $DEB_FILE"

echo ">>> Step 9: SCP .deb to remote server"
scp "$DEB_FILE" root@ngfw.untangle.com:/tmp/

echo ">>> Step 10: Install .deb and reboot remote server (combined)"
ssh root@ngfw.untangle.com "dpkg -i /tmp/untangle-vue-ui_17.4.0*.deb && reboot"


echo ">>> DONE — Remote system is rebooting"
