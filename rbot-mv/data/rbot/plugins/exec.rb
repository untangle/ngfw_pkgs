require 'optparse'

class SyntaxException < Exception
end

class ExecPlugin < Plugin

  def initialize
    super()
  end

  def handleOptions(args)
    i = args.index("--")

    if not i then
      raise SyntaxException.new help(nil)
      return
    end

    execOpts = args[0...i]
    command = args[i+1..-1].join(" ")

    options = {}

    opts = OptionParser.new { |opts|
      opts.on("-q", "--quiet",
              "Don't output the return code") { |ext|
                options[:quiet] = true
      }
      opts.on("-j", "--join-on-test <#channel>",
              "Join the given channel if the command succeeds") { |channel|
                options[:channel] = channel
                options[:quiet] = true
      }
    }

    opts.parse!(execOpts)

    return options, command
  end

  def runSystemCommand(command)
    output = `sudo su -c "#{command}" 2>&1`
    rc = $? >> 8
    return output, rc
  end

  def exec(m, params)
    begin
      options, command = handleOptions(params[:args])

      output, rc = runSystemCommand(command)
      m.reply output
      m.reply "*** RC = #{rc}" if not options.include?(:quiet)
      if options.include?(:channel) and rc == 0 then
        @bot.join(options[:channel])
        @bot.action(m.replyto, "joined #{options[:channel]}")
      end
    rescue SyntaxException => e
      handleException(m, e, false)
    rescue Exception => e
      handleException(m, e)
    end
  end

  def handleException(m, e, printStackTrace = true)
    m.reply "An exception happened: #{e.class} -> #{e.message}"
    if printStackTrace then
      e.backtrace.each { |line|
        m.reply "  #{line}"
      }
      m.reply "End of exception backtrace"
    end
  end

  def help(plugin, topic="")
    <<-eos
      exec [--quiet|-q] [-j|--join-on-test <#channel>] -- *command => Run command
    eos
  end

end

plugin = ExecPlugin.new
plugin.map 'exec *args', :action => 'exec'

