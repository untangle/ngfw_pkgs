#! /usr/local/bin/ruby

require 'cgi'

# custom modules
require 'db'
require 'utils'

begin
  cgi = CGI.new
  
  uk = UntangleKey.new

  baseDir = getTmpDir
  mvDir = "#{baseDir}/usr/share/metavize"
  File.makedirs(mvDir) 

  ip = cgi.remote_addr

  if cgi.key?('license_key') and cgi['license_key'] != ""
    licenseKey = cgi['license_key']
    if not licenseKey =~ /(\w{4}-){3}\w{4}/
      raise Exception.new('Badly formatted license key, aborting...')
    end
    uk.insertKey(licenseKey, ip)
  else
    if ip =~ /10\..*/ # from our own subnet, use the common license key
      licenseKey = '0127-47a7-bbff-0752'
      uk.insertKey(licenseKey, ip)
    else
      licenseKey = uk.getNewKey(ip)
    end
  end
  
  File.open("#{mvDir}/activation.key", 'w') { |f|
    f.puts(licenseKey)
  }

  tarFile = "#{getTmpFilePath('_archive_')}.tar"
  system "tar -C #{baseDir} -cf #{tarFile} ."

  puts "Content-Type: application/x-Tar"
  puts "Status: 200 OK"
  puts
  puts File.open(tarFile, 'rb').read
rescue Exception => e
  puts "Content-Type: text/plain"
  puts "Status: 500 Error"
  puts
  puts "Key couldn't be downloaded: #{e.message}"  
  e.backtrace.each { |line|
    puts "  #{line}"
  }
ensure
  uk.close
  system "rm -fr #{baseDir}"
  system "rm -fr #{tarFile}"
end
