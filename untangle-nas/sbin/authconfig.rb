#
# rush script to connect to UVM to answer the authconfig questions
#

nm = Untangle::RemoteUvmContext.nodeManager()
tid = nm.nodeInstances( 'untangle-node-nas' ).first()
nas = nm.nodeContext( tid ).node()

settings = nas.getNasSettings()

@smb_workgroup = settings['smbWorkgroup']
@netbios_name = settings['netbiosName']
@use_ldap = settings['useLdap']
@use_ad = settings['useAD']

if @use_ad
  addrbook = Untangle::RemoteUvmContext.appAddressBook()
  ab_settings = addrbook.getAddressBookSettings()
  ab_conf = ab_settings.getAddressBookConfiguration()
  if ab_conf.getKey() != ?B
    # ab configuration doesn't match setting of use_ad!
    @use_ad = false
  else
    repo_settings = ab_settings.getADRepositorySettings()
    @ad_realm = repo_settings.getDomain()
    @ad_master = repo_settings.getLDAPHost().upcase()
  end
end

def usage()
  puts "usage: authconfig.rb --get | --set"
  exit -2
end

###############################################################################

def set()
  puts "implement me"
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
  puts @use_ad ? "YES" : "NO";

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
  puts "cn=admin"

  # ldap root bind pw 40
  puts "nimda11lacol"
end

###############################################################################

unless ARGV.length == 1
  usage()
end
if ARGV[0] == "--get" then
  get()
elsif ARGV[0] == "--set" then
  set()
end
exit 0

