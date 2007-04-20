#!/usr/bin/env /usr/bin/ruby

require 'fcgi'

CVS_ROOT = '/var/lib/diffserver/cvs'
WORK_DIR = '/var/lib/diffserver/list'
CVS_DIFF = "cvs -d #{CVS_ROOT} diff -u"

HEADER = "Content-Type: text/plain\n\n"

def get_update(name, bl_version)
  rcs_version = bl_version.sub(/:/, '.')

  f = IO.popen("#{CVS_DIFF} -r#{rcs_version} -rHEAD #{WORK_DIR}/#{name}",
               mode='r') do |io|
    first_line = true
    io.each_line do |l|
      l.strip!
      if first_line then
        if /^\+\+\+.*([0-9]+\.[0-9]+)$/ =~ l then
          print "[#{name} #{$1.sub(/\./, ':')} update]\n"
          first_line = false
        end
      elsif /^[+-]/ =~ l then
        print "#{l}\tc\n"
      end
    end
  end
end

FCGI.each_cgi do |cgi|
  version = cgi.params["version"][0]

  print HEADER

  if version then
    version.split(',').each do |v|
      if /(.*):([0-9]+:[0-9]+)/ =~ v
        name = $1
        bl_version =  $2
        get_update(name, bl_version)
      end
    end
  end
end
