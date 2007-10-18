class ::OSLibrary::Debian::OS
  include Alpaca::OS

  def distribution
    File.open( "/etc/issue" ) { |f| f.readline.gsub( /(\\n|\\l)/, "" ).strip }
  end
end
