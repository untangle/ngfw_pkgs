blockRe = /^Package:\s*(.+?)\n.*?(Pin:\s*version\s+.+?)?.*?Pin-Priority:\s*\d+/m
versionTemplate = "\nPin: version %s\n"

ARGV.each { |fileName|
  print "#{File.basename(fileName)}: "

  blocks = {}
  
  File.open(fileName).read.split(/\n\n+/).each { |block|
    print "."
    STDOUT.flush
    block =~ blockRe
    name, version = $1, $2
    if version.nil? then
      version = `rmadison -s testing #{name}`.split[2]
      block.sub!(/\n/, versionTemplate % [version,])
    end
    blocks[name] = block
  }

  newContent = blocks.keys.sort.map { |name| blocks[name] }.join("\n\n")
  
  File.open(fileName, 'w').write(newContent + "\n")

  puts
}
