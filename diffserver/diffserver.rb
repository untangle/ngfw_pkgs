#!/usr/bin/ruby

def head_version(name)
  /head: ([0-9]+.[0-9]+)/ =~ `rlog -h #{name}`
  $1
end

def get_update(name, bl_version)
  rcs_version = bl_version.sub(/:/, '.')
  rcs_head = head_version(name)
  if rcs_version != rcs_head then
    puts "[#{name} #{rcs_head.sub(/\./, ':')} update]"

    f = IO.popen("rcsdiff -r#{rcs_version} -r#{rcs_head} #{name} 2>/dev/null",
                 mode="r") do |io|
      io.each_line do |l|
        if /^> (.*)$/ =~ l then
          puts "+#{$1}"
        elsif /^< (.*)$/ =~ l then
          puts "-#{$1}"
        end
      end
    end
  end
end

get_update(ARGV[0], ARGV[1])
