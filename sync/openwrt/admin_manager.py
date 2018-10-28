import crypt
import os
import stat
import sys
import subprocess
import datetime
import traceback
from sync import registrar
from sync import nftables_util

# This class is responsible for managing the "admin" (credentials) settings

class AdminManager:
    password_setter_filename = "/etc/config/startup.d/100-setpasswd"

    def initialize(self):
        registrar.register_file(self.password_setter_filename, "startup-scripts", self)
        pass

    def sanitize_settings(self, settings):
        admin = settings.get('admin')
        if admin is None:
            return
        creds = admin.get('credentials')
        if creds is None:
            return
        for cred in creds:
            cleartext_password = cred.get('passwordCleartext')
            if cleartext_password is None:
                continue
            print("Santizing password...")
            # Remove the cleartext password. We don't want to save this.
            del cred['passwordCleartext']
            # Replace with the hashed versions of the password
            cred['passwordShadowHash'] = crypt.crypt(cleartext_password, crypt.mksalt(crypt.METHOD_SHA512))
        return

    def validate_settings(self, settings):
        pass

    def create_settings(self, settings, prefix, delete_list, filename):
        print("%s: Initializing settings" % self.__class__.__name__)
        settings['admin'] = {}
        settings['admin']['credentials'] = [{
            "username": "admin",
            "passwordCleartext": "passwd"
        }]
        pass

    def sync_settings(self, settings, prefix, delete_list):
        admin = settings.get('admin')
        if admin is None:
            return
        creds = admin.get('credentials')
        if creds is None:
            return

        # prefer "root" user for root password
        # if "root" doesn't exist use "admin"
        # if neither exist, don't set root password
        for cred in creds:
            if cred["username"] == "root":
                self.write_password_setter(cred["passwordShadowHash"], prefix)
                return
        for cred in creds:
            if cred["username"] == "admin":
                self.write_password_setter(cred["passwordShadowHash"], prefix)
                return
        # if not found, delete any previous password script
        delete_list.append(password_setter_filename)
        return

    def write_password_setter(self, phash, prefix):
        filename = prefix + self.password_setter_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("#!/bin/sh")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        file.write('TMPFILE=`mktemp --tmpdir shadow.XXXXX`\n')
        file.write('/bin/sed -e \'s|^\\(root:\\)[^:]*\\(:.*\\)$|\\1')
        file.write(phash.replace("$","\$"))
        file.write('\\2|\' /etc/shadow > $TMPFILE\n')
        file.write('\n')

        file.write('if ! diff /etc/shadow $TMPFILE >/dev/null 2>&1 ; then cp $TMPFILE /etc/shadow ; fi\n')
        file.write('\n')

        file.write('rm -f $TMPFILE')
        file.write('\n')

        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("AdminManager: Wrote %s" % filename)
        return

registrar.register_manager(AdminManager())
