class ExecPlugin < Plugin

  def initialize
    super()
  end

  def exec(m, params)
    command = params[:command].join(" ")
    begin
      output = `#{command} 2>&1`
      rc = $? >> 8
      m.reply output
      m.reply "RC = #{rc}"
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
    eos
  end

end

plugin = ExecPlugin.new
plugin.map 'exec *command', :action => 'exec'
