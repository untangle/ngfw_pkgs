#! /usr/local/bin/ruby

require 'tempfile'
require 'cgi'

# custom modules
require 'db'
require 'utils'

begin
  cgi = CGI.new

  if not cgi.key?('license_key')
    raise Exception.new('Missing CGI parameter license_key')
  end

  licenseKey = cgi['license_key']
  ip = cgi.remote_addr

  uk = UntangleKey.new

  licenseKeyID = uk.getLicenseKeyIDByLicenseKeyAndIP(licenseKey, ip)

  if not licenseKeyID
    # this is an Untangle Server, for which we don't have the key in
    # this DB yet
    licenseKeyID = uk.insertLicenseKey(licenseKey, ip)
  end

  # we force-issue a new key even if a new one was issued before...
  baseDir = getTmpDir
  myDir = "#{baseDir}/.ssh"
  File.makedirs(myDir) 
  system "chmod 700 #{myDir}"

  passphrase = generatePassphrase

  privateKeyFile = "#{myDir}/key.dsa"
  publicKeyFile = "#{privateKeyFile}.pub"

  generateKey(passphrase, privateKeyFile)
  privateKey = readFile(privateKeyFile)
  publicKey = readFile(publicKeyFile)

  dsaKey = uk.getDSAKeyIDByLicenseKeyID(licenseKeyID)

  if dsaKey
    dsaKeyID = dsaKey['id']
    uk.updateDsaKey(dsaKeyID, licenseKeyID, privateKey, publicKey, passphrase)
  else
    uk.insertDsaKey(licenseKeyID, privateKey, publicKey, passphrase)
  end


  tarFile = "#{getTmpFilePath('_archive_')}.tar"
  system "tar -C #{baseDir} -cf #{tarFile} ."

  # it'd be better to write to authorizedKeysFile directly, but this belongs to another user
  # so we revert to 1) writing to a tempfile, and 2) sudo cp it in place
  authorizedKeysFile = '/home/rbot/.ssh/authorized_keys2'
  tmpFile = getTmpFilePath('_authorized_keys2_')
  File.open(tmpFile, 'w') { |f|
    uk.getAllPublicKeys.each { |row| 
      f.write(row)
    }
  }
  system("sudo /bin/cp -f #{tmpFile} /home/rbot/.ssh/authorized_keys2")

  # issue the HTTP response
  puts "Content-Type: application/x-Tar"
  puts "Status: 200 OK"
  puts
  puts File.open(tarFile, 'rb').read

#  puts "HTTP/1.0 200 OK"
#  puts  "Content-Type: text/plain"
#  puts
#  puts "#{privateKey}MYSEPARATOR#{publicKey}"
rescue Exception => e
  puts "Content-Type: text/plain"
  puts "Status: 500 Error"
  puts
  e.backtrace.each { |line|
    puts "  #{line}"
  }
ensure
  begin
    File.delete(tmpFile)
    system "rm -fr #{baseDir}"
    uk.close
  rescue
  end
end
