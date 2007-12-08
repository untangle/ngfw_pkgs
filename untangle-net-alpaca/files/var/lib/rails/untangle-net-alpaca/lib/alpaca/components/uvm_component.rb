class Alpaca::Components::UvmComponent < Alpaca::Component

  def wizard_insert_closers( builder )
    builder.insert_piece( Alpaca::Wizard::Closer.new( 1900 ) { save } )
  end

  private
  def save
    uvm_settings = UvmSettings.new
    uvm_settings.interface_order = UvmHelper::DefaultOrder
    UvmSettings.destroy_all

    uvm_settings.save
  end
  
end
