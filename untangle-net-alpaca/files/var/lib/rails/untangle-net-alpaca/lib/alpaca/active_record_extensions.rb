module Alpaca::ActiveRecordExtensions
  module ExtensionClassMethods
    def ordered_find( *args )
      found = false
      
      args.each do |a| 
        next unless a.is_a? Hash 
        a[:order] = order_field 
        found = true
        break
      end
      
      args << { :order => order_field } unless found
      
      ## Return the new fixed args
      find( *args )
    end
  end

  def self.append_features(mod)
    #  help out people counting on transitive mixins
    unless mod.instance_of?(Class)
      raise TypeError, "Inclusion of an ActiveRecordExtensions in a module #{mod}"
    end
    super
  end
  
  def self.included(klass)
    super
    klass.extend( ExtensionClassMethods )
  end
  
  ## included module must define a method named order_field that defines the order
end
