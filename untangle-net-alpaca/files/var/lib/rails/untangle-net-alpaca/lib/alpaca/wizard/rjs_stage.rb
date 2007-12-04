class Alpaca::Wizard::RjsStage < Alpaca::Wizard::Stage
  def initialize( id, name, priority, rjs )
    super( id, name, priority )
    @rjs = rjs
  end

  def partial
    "placeholder"
  end

  attr_reader :rjs
end
