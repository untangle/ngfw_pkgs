# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  # return true if a field is nil or null.
  def ApplicationHelper.null?( field )
    return true if field.nil?
    field = field.strip
    return true if field.empty?
    return true if ( field.upcase == "NULL" )    
    false
  end
end
