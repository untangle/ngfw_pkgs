"""This class is responsible for writing interface-marks chains"""
# pylint: disable=unused-argument
# pylint: disable=too-many-statements
# pylint: disable=no-self-use
import os
import stat
from sync import registrar, Manager

class InterfaceManager(Manager):
    """InterfaceManager writes /etc/config/nftables-rules.d/101-interface-marks"""
    INTERFACE_MARKS_FILENAME = "/etc/config/nftables-rules.d/101-interface-marks"

    SRC_INTERFACE_MASK = 0x000000ff
    SRC_INTERFACE_MASK_INVERSE = 0xffffff00
    SRC_INTERFACE_SHIFT = 0
    DST_INTERFACE_MASK = 0x0000ff00
    DST_INTERFACE_MASK_INVERSE = 0xffff00ff
    DST_INTERFACE_SHIFT = 8
    CLIENT_INTERFACE_MASK = 0x000000ff
    CLIENT_INTERFACE_MASK_INVERSE = 0xffffff00
    CLIENT_INTERFACE_SHIFT = 0
    SERVER_INTERFACE_MASK = 0x0000ff00
    SERVER_INTERFACE_MASK_INVERSE = 0xffff00ff
    SERVER_INTERFACE_SHIFT = 8
    SRC_TYPE_MASK = 0x03000000
    SRC_TYPE_MASK_INVERSE = 0xfcffffff
    SRC_TYPE_SHIFT = 24
    DST_TYPE_MASK = 0x0c000000
    DST_TYPE_MASK_INVERSE = 0xf3ffffff
    DST_TYPE_SHIFT = 26
    CLIENT_TYPE_MASK = 0x03000000
    CLIENT_TYPE_MASK_INVERSE = 0xfcffffff
    CLIENT_TYPE_SHIFT = 24
    SERVER_TYPE_MASK = 0x0c000000
    SERVER_TYPE_MASK_INVERSE = 0xf3ffffff
    SERVER_TYPE_SHIFT = 26
    ALL_MASK = 0x0f00ffff
    LOCAL_INTERFACE_ID = 0xff #255

    def initialize(self):
        """initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.INTERFACE_MARKS_FILENAME, "restart-nftables-rules", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        """syncs settings"""
        self.write_interface_marks_file(settings_file.settings, prefix)

    def write_interface_marks_file(self, settings, prefix):
        """write_interface_marks_file writes /etc/config/nftables-rules.d/101-interface-marks"""
        filename = prefix + self.INTERFACE_MARKS_FILENAME
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("#!/usr/bin/nft_debug -f")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        file.write(r"""
add table inet interface-marks
flush table inet interface-marks
add chain inet interface-marks prerouting-interface-marks { type filter hook prerouting priority -150 ; }
add chain inet interface-marks forward-interface-marks { type filter hook forward priority -150 ; }
add chain inet interface-marks postrouting-interface-marks { type filter hook postrouting priority 0 ; }
add chain inet interface-marks output-interface-marks { type filter hook output priority -150 ; }
add chain inet interface-marks input-interface-marks { type filter hook input priority -150 ; }
add chain inet interface-marks restore-interface-marks
add chain inet interface-marks restore-interface-marks-original
add chain inet interface-marks restore-interface-marks-reply
add rule inet interface-marks restore-interface-marks ct direction original jump restore-interface-marks-original
add rule inet interface-marks restore-interface-marks ct direction reply jump restore-interface-marks-reply
add chain inet interface-marks mark-src-interface
add chain inet interface-marks mark-dst-interface
add rule inet interface-marks prerouting-interface-marks jump restore-interface-marks
add rule inet interface-marks prerouting-interface-marks ct state new jump mark-src-interface
add rule inet interface-marks prerouting-interface-marks mark and 0x000000ff == 0 jump mark-src-interface

# If its a new session - we set the mark the dst interface marks regardless of what they were set to before
# often we will set them prerouting to "vote" for a specific interface, but that may not be the actual dst interface 
# after the routing table is consulted (it could have been overridden by a local route for example)
# in this case we need to reset the dst interface mark to the correct & actual dst interface mark
add rule inet interface-marks forward-interface-marks ct state new jump mark-dst-interface

# sometimes sessions were created before these rules were in place - still mark these
add rule inet interface-marks postrouting-interface-marks mark and 0x0000ff00 == 0 jump mark-dst-interface
add rule inet interface-marks postrouting-interface-marks ct state new jump mark-dst-interface

# make sure we restore interface marks on local output traffic so we see return traffic as already routed
add rule inet interface-marks output-interface-marks jump restore-interface-marks
""")

        # input-interface-marks doesn't mark broadcast or multicast sessions
        # These sessions have multiple destinations and so setting the dest/server mark to 0xff does not make much sense
        file.write("add rule inet interface-marks input-interface-marks ct state new fib daddr type != { broadcast, multicast } ct mark set ct mark and 0x%x or 0x%x\n" %
                   (self.SERVER_INTERFACE_MASK_INVERSE, (self.LOCAL_INTERFACE_ID << self.SERVER_INTERFACE_SHIFT)))
        file.write("add rule inet interface-marks input-interface-marks mark set mark and 0x%x or 0x%x\n" %
                   (self.DST_INTERFACE_MASK_INVERSE, (self.LOCAL_INTERFACE_ID << self.DST_INTERFACE_SHIFT)))

        file.write("add rule inet interface-marks output-interface-marks ct state new ct mark set ct mark and 0x%x or 0x%x\n" %
                   (self.CLIENT_INTERFACE_MASK_INVERSE, (self.LOCAL_INTERFACE_ID << self.CLIENT_INTERFACE_SHIFT)))
        file.write("add rule inet interface-marks output-interface-marks ct state new ct mark set ct mark and 0x%x or 0x%x\n" %
                   (self.CLIENT_TYPE_MASK_INVERSE, (2 << self.CLIENT_TYPE_SHIFT) & self.CLIENT_TYPE_MASK))
        file.write("add rule inet interface-marks output-interface-marks mark set mark and 0x%x or 0x%x\n" %
                   (self.SRC_INTERFACE_MASK_INVERSE, (self.LOCAL_INTERFACE_ID << self.SRC_INTERFACE_SHIFT)))
        file.write("add rule inet interface-marks output-interface-marks mark set mark and 0x%x or 0x%x\n" %
                   (self.SRC_TYPE_MASK_INVERSE, (2 << self.SRC_TYPE_SHIFT) & self.SRC_TYPE_MASK))
        # We don't set/restore marks in output because there is no src/client mark
        # and the dst/server mark is handled in postrouting

        interfaces = settings.get('network').get('interfaces')
        for intf in interfaces:
            if not intf.get('enabled'):
                continue
            if intf.get('configType') == 'BRIDGED':
                continue

            # just use the normal interface name
            # unless its a bridge and then use the bridge zone interface name
            interface_name = intf.get('netfilterDev')
            interface_type = 2 # lan
            if intf.get('wan'):
                interface_type = 1 # wan
            interface_id = intf.get('interfaceId')

            file.write("# set source interface mark\n")
            file.write("add rule inet interface-marks mark-src-interface iifname %s mark set mark and 0x%x or 0x%x\n" %
                       (interface_name, self.SRC_INTERFACE_MASK_INVERSE, (interface_id << self.SRC_INTERFACE_SHIFT) & self.SRC_INTERFACE_MASK))
            file.write("# set source interface type\n")
            file.write("add rule inet interface-marks mark-src-interface iifname %s mark set mark and 0x%x or 0x%x\n" %
                       (interface_name, self.SRC_TYPE_MASK_INVERSE, (interface_type << self.SRC_TYPE_SHIFT) & self.SRC_TYPE_MASK))
            file.write("# set client interface mark\n")
            file.write("add rule inet interface-marks mark-src-interface ct direction original iifname %s ct mark set ct mark and 0x%x or 0x%x\n" %
                       (interface_name, self.CLIENT_INTERFACE_MASK_INVERSE, (interface_id << self.CLIENT_INTERFACE_SHIFT) & self.CLIENT_INTERFACE_MASK))
            file.write("# set client interface type\n")
            file.write("add rule inet interface-marks mark-src-interface ct direction original iifname %s ct mark set ct mark and 0x%x or 0x%x\n" %
                       (interface_name, self.CLIENT_TYPE_MASK_INVERSE, (interface_type << self.CLIENT_TYPE_SHIFT) & self.CLIENT_TYPE_MASK))

            file.write("# set destination interface mark\n")
            file.write("add rule inet interface-marks mark-dst-interface oifname %s mark set mark and 0x%x or 0x%x\n" %
                       (interface_name, self.DST_INTERFACE_MASK_INVERSE, (interface_id << self.DST_INTERFACE_SHIFT) & self.DST_INTERFACE_MASK))
            file.write("# set destination interface type\n")
            file.write("add rule inet interface-marks mark-dst-interface oifname %s mark set mark and 0x%x or 0x%x\n" %
                       (interface_name, self.DST_TYPE_MASK_INVERSE, (interface_type << self.DST_TYPE_SHIFT) & self.DST_TYPE_MASK))
            file.write("# set server interface mark\n")
            file.write("add rule inet interface-marks mark-dst-interface ct direction original oifname %s ct mark set ct mark and 0x%x or 0x%x\n" %
                       (interface_name, self.SERVER_INTERFACE_MASK_INVERSE, (interface_id << self.SERVER_INTERFACE_SHIFT) & self.SERVER_INTERFACE_MASK))
            file.write("# set server interface type\n")
            file.write("add rule inet interface-marks mark-dst-interface ct direction original oifname %s ct mark set ct mark and 0x%x or 0x%x\n" %
                       (interface_name, self.SERVER_TYPE_MASK_INVERSE, (interface_type << self.SERVER_TYPE_SHIFT) & self.SERVER_TYPE_MASK))

            file.write("# if ct mark server interface is X then set the mark client interface to X\n")
            file.write("add rule inet interface-marks restore-interface-marks-reply ct mark and 0x%x == 0x%x mark set mark and 0x%x or 0x%x\n" %
                       (self.SERVER_INTERFACE_MASK, (interface_id << self.SERVER_INTERFACE_SHIFT), self.CLIENT_INTERFACE_MASK_INVERSE, interface_id << self.CLIENT_INTERFACE_SHIFT))
            file.write("# if ct mark server interface is X then set the mark client type to Xs type\n")
            file.write("add rule inet interface-marks restore-interface-marks-reply ct mark and 0x%x == 0x%x mark set mark and 0x%x or 0x%x\n" %
                       (self.SERVER_INTERFACE_MASK, (interface_id << self.SERVER_INTERFACE_SHIFT), self.CLIENT_TYPE_MASK_INVERSE, interface_type << self.CLIENT_TYPE_SHIFT))
            file.write("# if ct mark client interface is X then set the mark server interface to X\n")
            file.write("add rule inet interface-marks restore-interface-marks-reply ct mark and 0x%x == 0x%x mark set mark and 0x%x or 0x%x\n" %
                       (self.CLIENT_INTERFACE_MASK, (interface_id << self.CLIENT_INTERFACE_SHIFT), self.SERVER_INTERFACE_MASK_INVERSE, interface_id << self.SERVER_INTERFACE_SHIFT))
            file.write("# if ct mark client interface is X then set the mark server type to Xs type\n")
            file.write("add rule inet interface-marks restore-interface-marks-reply ct mark and 0x%x == 0x%x mark set mark and 0x%x or 0x%x\n" %
                       (self.CLIENT_INTERFACE_MASK, (interface_id << self.CLIENT_INTERFACE_SHIFT), self.SERVER_TYPE_MASK_INVERSE, interface_type << self.SERVER_TYPE_SHIFT))

        file.write("# restore reply direction interface marks for local output traffic\n")
        file.write("add rule inet interface-marks restore-interface-marks-reply ct mark and 0x%x == 0x%x mark set mark and 0x%x or 0x%x\n" %
                   (self.SERVER_INTERFACE_MASK, (255 << self.SERVER_INTERFACE_SHIFT), self.CLIENT_INTERFACE_MASK_INVERSE, 255 << self.CLIENT_INTERFACE_SHIFT))
        file.write("add rule inet interface-marks restore-interface-marks-reply ct mark and 0x%x == 0x%x mark set mark and 0x%x or 0x%x\n" %
                   (self.CLIENT_INTERFACE_MASK, (255 << self.CLIENT_INTERFACE_SHIFT), self.SERVER_INTERFACE_MASK_INVERSE, 255 << self.SERVER_INTERFACE_SHIFT))

        file.write("# restore original direction interface marks\n")
        file.write("add rule inet interface-marks restore-interface-marks-original mark set ct mark and 0x%x\n" % (self.ALL_MASK))

        file.write("add rule inet interface-marks prerouting-interface-marks mark and 0x%x == 0 iifname != lo log prefix \"WARNING: Unknown src intf: \"\n" % (self.SRC_INTERFACE_MASK))
        file.write("add rule inet interface-marks postrouting-interface-marks mark and 0x%x == 0 oifname != lo log prefix \"WARNING: Unknown dst intf: \"\n" % (self.DST_INTERFACE_MASK))

        # We could just have static rules in restore-interface-marks-reply that just apply the original marks but shifted around a bit
        # However This would require something like:
        # mark set mark or ct mark and 0xff << 8
        # However nft won't let you do this:
        # Error: Right hand side of binary operation (|) must be constant
        # So we have to use a ton of rules to do the same thing above

        file.write("\n")
        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("InterfaceManager: Wrote %s" % filename)
        return

registrar.register_manager(InterfaceManager())
