class ExecPlugin < Plugin

  def initialize
    super()
  end

  def runSystemCommand(command)
    output = `sudo su -c "#{command}" 2>&1`
    rc = $? >> 8
    return output, rc
  end

  def exec(m, params)
    begin
      command = params[:command].join(" ")
      output, rc = runSystemCommand(command)
      m.reply output
      m.reply "*** RC = #{rc}"
    rescue Exception => e
      handleException(m, e)
    end
  end

  def extendTrial(m, params)
    exec(m, { :command => "./extend_trial.sh" })
  end

  def joinOnTest(m, params)
    begin
      command = params[:command].join(" ")
      output, rc = runSystemCommand(command)
      if rc == 0
        @bot.join(params[:channel])
        @bot.action("joined #{params[:channel]}")
      end
    rescue Exception => e
      handleException(m, e)
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
      ssh exec *command => Run command
      ssh join_on_test #channel *command => if command succeeds, join #channel
    eos
  end

end

plugin = ExecPlugin.new
plugin.map 'exec *command', :action => 'exec'
plugin.map 'join_on_test :channel *command', :action => 'joinOnTest'
plugin.map 'extend_trial', :action => 'extendTrial'
