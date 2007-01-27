require 'net/ssh'
require 'net/ssh/util/prompter'
require 'net/ssh/service/forward/remote-network-handler'
require 'net/ssh/transport/ossl/key-factory'

class Net::SSH::Util::Prompter
  # FIXME: there has to be a way to use my own prompter instead of
  # redefining the behavior of the stock one.

  @@passphrase = ""

  def self.passphrase=(passphrase)
    @@passphrase = passphrase
  end

  def password(prompt)
    return @@passphrase
  end
end

class Net::SSH::Service::Forward::RemoteNetworkHandler
  # We redefine the behavior of .setup so that we can inform
  # the user when the channel has actually been established
  # and only then

  @@m = nil
  @@sshplugin = nil

  def self.init(p, m) # class method
    @@sshplugin = p
    @@m = m
  end

  def setup(remote_port)
    @@m.reply "Forwarding channel established on port #{remote_port}"
  end

  def on_close( channel )
    @@m.reply "SSH connection closed -> tearing down the forwarding channel"
    @@sshplugin.close
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
    @portAttempts = 0
  end

  def pickRandomPort
    @port = 1025 + rand(10000) # a random port to use for forwarding
#    @port = 1234
    @portAttempts += 1
  end

  def enable(m, params)
    @m = m

    if @isEstablished
      m.reply "The forwarding channel is already enabled on port #{@port}" 
      return
    end

    Net::SSH::Util::Prompter.passphrase = params[:passphrase]
    # FIXME: find a better design pattern than this crap !!!
    Net::SSH::Service::Forward::RemoteNetworkHandler.init self, m

    @thread = Thread.new do # start the forwarded channel in a thread
      begin
        pickRandomPort

        Net::SSH.start(@host, @user,
                       :auth_methods => [ "publickey" ],
                       :keys => [ @key ] ) do |@session|
          # "0.0.0.0" is for binding on all interfaces, so support can
          # use the forwarded channel from any box on the Untangle
          # network
          @session.forward.remote_to(22, 'localhost', @port, '0.0.0.0')

          # At this point maybe the forwarding channel isn't
          # established, but if it's the case we'll hit an exception
          # and set @isEstablished  back to false
          @isEstablished = true
          @portAttempts = 0

          # next line doesn't work as advertised in Net::SSH doc
          # @session.loop { !@needToStop }
          @session.loop { true }
        end
      rescue OpenSSL::PKey::RSAError => e
        if e.message =~ /Neither PUB key nor PRIV key/
          m.reply "Forwarding channel not setup: invalid passphrase"
        else
          handleException m, e
        end
      rescue Net::SSH::AuthenticationFailed => e
        if e.message =~ /#{@user}/
          m.reply "Forwarding channel not setup: could not find SSH key"
        else
          handleException m, e
        end
      rescue Net::SSH::Exception => e
        if e.message =~ /closed by remote host/
          m.reply "Forwarding channel closed on port #{@port}"
        elsif e.message =~ /remote port #{@port} could not be forwarded to local host/
          while @portAttempts < 10
            retry
          end
          m.reply "Could not find a free port to setup forwarding channel on, giving up"
        else
          handleException m, e
        end
      rescue Exception => e
        handleException m, e
      ensure
        begin
          @session.close
        rescue # do nothing...
        end
        @isEstablished = false
        @portAttempts = 0
      end
    end
  end

  def close
    @session.close
  end

  def disable(m, params)
    if @isEstablished
      m.reply "Received request to disable forwarding channel on port #{@port}"
#      @needToStop = true
      close
    else
      m.reply "Forwarding channel is not established, ignoring request"
    end
  end

  def handleException(m, e)
    m.reply "An exception happened: #{e.class} -> #{e.message}"
     e.backtrace.each { |line|
       m.reply "  #{line}"
     }
    m.reply "End of exception backtrace"
  end

  def help(plugin, topic="")
    <<-eos
      ssh enable :passphrase => Enable SSH forwarding channel
      ssh disable            => Disable SSH forwarding channel
    eos
  end

end

plugin = SSHPlugin.new "10.0.10.100", "client1", "/root/client-key.dsa"
plugin.map 'ssh enable :passphrase', :action => 'enable'
plugin.map 'ssh disable', :action => 'disable'
