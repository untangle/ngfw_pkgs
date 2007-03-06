require 'tempfile'
require 'ftools'

def getTmpFilePath(basename)
  tmpFile = Tempfile.new(basename)
  tmpFile.close(true)
  return tmpFile.path
end

def getTmpDir
  # FIXME: copyright Janky2007...
  tmpFilePath = getTmpFilePath('_foo_')
  File.safe_unlink(tmpFilePath)
  File.makedirs(tmpFilePath)
  return tmpFilePath
end

def generatePassphrase
  passphraseLength = 10 + rand(4)
  passphrase = `/usr/local/bin/pwgen #{passphraseLength} 1`
  return passphrase.chomp
end

def generateKey(passphrase, file)
  system "ssh-keygen -t dsa -N '#{passphrase}' -f #{file} > /dev/null"
end

def readFile(file)
  s = ""
  File.open(file).each { |line| s << line }
  return s
end
