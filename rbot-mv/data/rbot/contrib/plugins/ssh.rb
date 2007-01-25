require 'net/ssh'
require 'net/ssh/util/prompter'
require 'net/ssh/transport/ossl/key-factory'

class Net::SSH::Util::Prompter
  # FIXME: there has to be a way to use my own prompter instead of
  # redefining the behavior of the stock one.

  @@passphrase = ""

  class << self
    def passphrase=(passphrase)
      @@passphrase = passphrase
    end
  end

  def password(prompt)
    return @@passphrase
  end
end

class SSHPlugin < Plugin
  # DISPLAY=:0 SSH_ASKPASS='echo $passphrase' ssh -i $key
  # -R $port:localhost:22 $user@$host
  # 'while true ; do sleep 5 ; done' < /dev/null

  def initialize(host, user, key)
    super()
    @host = host
    @user = user
    @key = key
    @port = nil
    @thread = nil
#    @needToStop = false
    @isEstablished = false
  end

  def enable(m, params)
    if @isEstablished
      m.reply "The forwarding channel is already enabled on port #{@port}" 
      return
    end

    if not params[:passphrase]
      m.reply "You need a passphrase" 
      return
    else
      Net::SSH::Util::Prompter.passphrase = params[:passphrase]
    end

    # @port = 1025 + rand(10000) # a random port to use for forwarding
    @port = 1234

    @thread = Thread.new do # start the forwarded channel in a thread
      Net::SSH.start(@host, @user,
                     :log => "/tmp/foo", # FIXME
                     :verbose => :info,
                     :auth_methods => [ "publickey" ],
                     :keys => [ @key ] ) do |@session|
        # do not bind only on lo, so support can use the forwarded
        # channel from any box on the Untangle network
        @session.forward.remote_to(22, 'localhost', @port, '0.0.0.0')
        m.reply "Forwarding channel established on port #{@port}"
        @isEstablished = true
        # doesn't seem to be needed
        # # keep the session alive using one ping every 30 seconds
        # @session.shell.open.ping "-i 30 localhost"
        
        # next line doesn't work as advertised in Net::SSH doc
        # @session.loop { !@needToStop }
        begin
          @session.loop { true }
        rescue Net::SSH::Exception => e
          unless e.message =~ /closed by remote host/
            raise
          end
          @isEstablished = false
        end
        m.reply "Forwarding channel closed on port #{@port}"
      end
    end
  end

  def disable(m, params)
    if @isEstablished
      m.reply "Received request to disable forwarding channel on port #{@port}"
#      @needToStop = true
      @session.close
      @thread.join
    else
      m.reply "Forwarding channel is not established, ignoring request"
    end
  end

  def help(plugin, topic="")
    <<-eos
      ssh enable :passphrase => Enable SSH forwarding channel
      ssh disable            => Disable SSH forwarding channel
    eos
  end

end

plugin = SSHPlugin.new "10.0.10.100", "client1", "/home/seb/client-key.dsa"
plugin.map 'ssh enable :passphrase', :action => 'enable'
plugin.map 'ssh disable', :action => 'disable'
