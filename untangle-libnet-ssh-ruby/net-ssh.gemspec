require './lib/net/ssh/version'

PKG_BUILD = ENV['PKG_BUILD'] ? ".#{ENV['PKG_BUILD']}" : ""

Gem::Specification.new do |s|

  s.name = 'net-ssh'
  s.version = Net::SSH::Version::STRING + PKG_BUILD
  s.platform = Gem::Platform::RUBY
  s.summary =
    "Net::SSH is a pure-Ruby implementation of the SSH2 client protocol."
  s.files = Dir.glob("{bin,doc,lib,examples,test}/**/*")
  s.files << "README"
  s.files << "LICENSE"
  s.files << "NEWS"
  s.files << "THANKS"
  s.files << "ChangeLog"
  s.require_path = 'lib'
  s.autorequire = 'net/ssh'

  s.bindir = "bin"
  s.executables << "rb-keygen"

  s.add_dependency 'needle', '>= 1.2.0'

  s.has_rdoc=true

  s.test_suite_file = 'test/ALL-TESTS.rb'

  s.author = "Jamis Buck"
  s.email = "jamis@37signals.com"
  s.homepage = "http://net-ssh.rubyforge.org"

end
