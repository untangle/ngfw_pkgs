#! /bin/bash

GPG_KEYS_DIR=/usr/share/untangle-spamassassin-update
SA_GPG_KEY=${GPG_KEYS_DIR}/sa.gpg
SARE_GPG_KEY=${GPG_KEYS_DIR}/sare.gpg

# download + import the GPG keys for both the official SA and SARE
curl --silent -o $SARE_GPG_KEY http://daryl.dostech.ca/sa-update/sare/GPG.KEY
curl --silent -o $SA_GPG_KEY http://spamassassin.apache.org/updates/GPG.KEY
chmod 700 /etc/spamassassin/sa-update-keys

sa-update --import $SA_GPG_KEY 2> /dev/null
sa-update --import $SARE_GPG_KEY 2> /dev/null
