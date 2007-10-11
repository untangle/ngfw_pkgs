class OSLibrary::Debian::OS
  include OSLibrary::OSBase
  include Singleton
  
  def kernel
    `uname -s -r`
  end
  
  ## This works on a default install of sarge and etch.
  def distribution
    File.open( "/etc/issue" ) { |f| f.readline.gsub( /(\\n|\\l)/, "" ).strip }
  end
end
