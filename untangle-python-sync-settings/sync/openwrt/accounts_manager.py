"Handles accounts/admin settings"
# pylint: disable=unused-argument
# pylint: disable=no-self-use
import crypt
import os
import stat
from sync import registrar

class AccountsManager:
    """AccountsManager is responsible for managing the "accounts" (credentials) settings"""
    password_setter_filename = "/etc/config/startup.d/100-setpasswd"

    def initialize(self):
        """initialize this module"""
        registrar.register_file(self.password_setter_filename, "startup-scripts", self)

    def sanitize_settings(self, settings):
        """sanitizes removes the cleartext password and replaces with the proper hashes"""
        accounts = settings.get('accounts')
        if accounts is None:
            return
        creds = accounts.get('credentials')
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
            cred['passwordHashMD5'] = crypt.crypt(cleartext_password, crypt.mksalt(crypt.METHOD_MD5))
            cred['passwordHashSHA512'] = crypt.crypt(cleartext_password, crypt.mksalt(crypt.METHOD_SHA512))
            cred['passwordHashSHA256'] = crypt.crypt(cleartext_password, crypt.mksalt(crypt.METHOD_SHA256))
        return

    def validate_settings(self, settings):
        """validates settings"""
        pass

    def create_settings(self, settings, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)
        settings['accounts'] = {}
        settings['accounts']['credentials'] = [{
            "username": "admin",
            "passwordCleartext": "passwd"
        }]

    def sync_settings(self, settings, prefix, delete_list):
        """syncs settings"""
        accounts = settings.get('accounts')
        if accounts is None:
            return
        creds = accounts.get('credentials')
        if creds is None:
            return

        # prefer "root" user for root password
        # if "root" doesn't exist use "admin"
        # if neither exist, don't set root password
        # In OpenWRT we must write the password in MD5 unfortunately
        # https://forum.openwrt.org/t/passwd-a-sha256-sha512-less-secure-than-default/13117
        for cred in creds:
            if cred["username"] == "root":
                self.write_password_setter(cred["passwordHashMD5"], prefix)
                return
        for cred in creds:
            if cred["username"] == "admin":
                self.write_password_setter(cred["passwordHashMD5"], prefix)
                return

        # if not found, delete any previous password script
        delete_list.append(self.password_setter_filename)
        return

    def write_password_setter(self, phash, prefix):
        """Write the script to set the password in /tmp/shadow"""
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

        file.write('TMPFILE="/tmp/shadow"\n')
        file.write('/bin/sed -e \'s|^\\(root:\\)[^:]*:[^:]*\\(:.*\\)$|\\1')
        file.write(phash.replace("$", r"\$"))
        file.write(':\\2|\' /etc/shadow > $TMPFILE\n')
        file.write('\n')

        file.write('if ! diff /etc/shadow $TMPFILE >/dev/null 2>&1 ; then cp $TMPFILE /etc/shadow ; fi\n')
        file.write('\n')

        file.write('rm -f $TMPFILE')
        file.write('\n')

        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("AccountsManager: Wrote %s" % filename)
        return

registrar.register_manager(AccountsManager())
