#
# rush script to connect to UVM to answer the authconfig questions
#

begin
  nm = Untangle::RemoteUvmContext.nodeManager()
  tid = nm.nodeInstances( 'untangle-node-nas' ).first()
  nas = nm.nodeContext( tid ).node()

  settings = nas.getNasSettings()

  @smb_workgroup = settings['smbWorkgroup']
  @netbios_name = settings['netbiosName']
  @server_string = settings['serverDescription']
  @use_ldap = settings['useLdap']
  @use_ad = true #settings['useAD']
  @webdav_enabled = nas.isDavEnabled()

  if @use_ad
    addrbook = Untangle::RemoteUvmContext.appAddressBook()
    ab_settings = addrbook.getAddressBookSettings()
    ab_conf = ab_settings['addressBookConfiguration']
    if ab_conf != 'AD_AND_LOCAL'
      # ab configuration doesn't match setting of use_ad!
      @use_ad = false
    else
      repo_settings = ab_settings['ADRepositorySettings']
      @ad_realm = repo_settings['domain'].upcase()
      @ad_master = repo_settings['LDAPHost']
    end
  end
rescue
  $stderr.puts "Unable to read settings from UVM: " + $!
  exit -1
end

def usage()
  $stderr.puts "usage: authconfig.rb --get | --set"
  exit -2
end

###############################################################################

def set()
  # /etc/nsswitch.conf
  if @use_ad && @use_ldap then
    nsline = "compat winbind ldap"
  elsif @use_ad then
    nsline = "compat winbind"
  elsif @use_ldap then
    nsline = "compat ldap"
  else
    nsline = "compat"
  end
  `sed -i -e "s/^\\(passwd\\|group\\|shadow\\):.*/\\1:	#{nsline}/" /etc/nsswitch.conf`

  # /etc/nss-ldapd.conf
  `sed -i -e "s/^base .*/base dc=nodomain/" -e "s-^uri .*-uri ldap://localhost:3899-" /etc/nss-ldapd.conf`

  # /etc/krb5.conf
  if @use_ad then
    File.open("/etc/krb5.conf", "w") do |f|
      f.puts <<EOF
[libdefaults]
        default_realm = #{@ad_realm}
        forwardable = true
#	dns_lookup_realm = false
#	dns_lookup_kdc = false

[realms]
        #{@ad_realm} = {
                kdc = #{@ad_master}
                admin_server = #{@ad_master}
                default_domain = #{@ad_realm.downcase()}
        }

[domain_realm]
.#{@ad_realm.downcase()} = #{@ad_realm}
EOF
    end
  end
end

def join()
  begin
    addrbook = Untangle::RemoteUvmContext.appAddressBook()
    addrbook.joinDomain(@smb_workgroup)
    `[ -x /etc/init.d/winbind ] && /etc/init.d/winbind restart`
  rescue
    $stderr.puts "Unable to join domain in UVM: " + $!
    exit -3
  end
end
  
###############################################################################

def get()
  # enable cache 0
  puts "NO"

  # YES
  puts "YES"

  # enable hesiod 2
  puts "NO"

  # hesiod lhs
  puts ""

  # hesiod rhs 4
  puts ""

  # enable ldap
  puts @use_ldap ? "YES" : "NO"

  # enable ldaps XX (applies locally or both?) 6
  puts "NO"

  # ldap server
  puts "localhost:3899"

  # ldap base dn 8
  puts "dc=nodomain"

  # enable nis 
  puts "NO"

  # nis server 10
  puts ""

  # nis domain
  puts ""

  # local policies (pam_stack, deprecated in recent versions) 12
  puts "YES"

  # enable shadow
  puts "YES"

  # enable md5 14
  puts "YES"

  # enable kerberos == use kerberos for system auth (non-AD kerberos)
  puts "NO"

  # kerberos realm  16
  puts @use_ad ? @ad_realm : "EXAMPLE.COM"

  # kerberos kdc
  puts @use_ad ? @ad_master : ""

  # kerberos admin server 18
  puts @use_ad ? @ad_master : ""

  # enable ldap auth
  puts "NO"

  # enable ldaps (again) 20
  puts "NO"

  # ldap server (again)
  puts "localhost:3899"

  # ldap base dn (again) 22
  puts "dc=nodomain"

  # enable smb (auth) Unused XX
  puts "NO"

  # smb workgroup 24
  puts @smb_workgroup

  # smb servers (winbindcontrollers)
  puts @use_ad ? @ad_master : ""

  # enable compat Unused XX 26
  puts "NO"

  # enable db Unused XX
  puts "NO"

  # enable nis3 28
  puts "NO"

  # enable winbind
  puts @use_ad ? "YES" : "NO"

  # enable wins 30
  puts "NO"

  # kerberos kdc via dns Unused XX
  puts "NO"

  # smb realm 32
  puts @use_ad ? @ad_realm : ""

  # smb security
  puts @use_ad ? "ads" : "user"

  # smb idmap uid 34
  puts "16777216-33554431"

  # smb idmap gid
  puts "16777216-33554431"

  # winbind template shell 36
  puts "/sbin/nologin"

  # ldap bind dn XX (authenticated bind dn)??
  puts ""

  # ldap bind pw XX (authenticated bind pw)?? 38
  puts ""

  # ldap root bind dn
  puts "cn=admin,dc=nodomain"

  # ldap root bind pw (no longer used in php) 40
  puts ""

##### After here is stuff added by Untangle
  # netbios name 41
  puts @netbios_name

  # server string  42
  puts @server_string

  # is WebDAV enabled? 43
  puts @webdav_enabled

end

###############################################################################

unless ARGV.length == 1
  usage()
end
if ARGV[0] == "--get" then
  get()
elsif ARGV[0] == "--set" then
  set()
  join()
end
exit 0

