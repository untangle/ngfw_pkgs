#enhancements to the helper functions
module ActionView
  module Helpers
    module FormTagHelper

      alias_method :orig_submit_tag, :submit_tag

      def submit_tag( value, options = {})
        result_prefix = ""
        result_suffix = ""

        css_class = "submit"

        #List of buttons with an icon:
        icon_submit = [ "Save", "Cancel", "Help" ]
       
        if icon_submit.include?( value )
          result_prefix = result_prefix + "<span class=\"iconbutton\"><span>"
          result_suffix = "</span></span>" + result_suffix
          css_class = css_class + " " + value
        end

        #IE6 does not support css attribute selectors
        #this impelements similar functionality server side by adding a class
        #so instead of input[type="submit"] you can use input.submit
        #for IE6 compatibility
        if options.include?( :class )
          css_class = options[:class] + " " + css_class
        end
        
        results = result_prefix + orig_submit_tag( value, options.merge( :class => css_class)) + result_suffix
      end
    end
  end
end
