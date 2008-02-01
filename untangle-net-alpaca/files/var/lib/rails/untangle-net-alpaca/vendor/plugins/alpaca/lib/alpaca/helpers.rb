#enhancements to the helper functions

module AlpacaShank
    def shank( side )
        self.insert( self.length / 2, side )
    end
end

class String
    include AlpacaShank
end

class Array
    include AlpacaShank
end

module ActionView
  module Helpers

    module FormHelper

      alias_method :orig_check_box, :check_box

      def check_box( object_name, method, options = {}, checked_value= "1", unchecked_value = "0" )
        css_class = "checkbox"
        
        if options.include?( :class )
          css_class = options[:class] + " " + css_class
        end

        orig_check_box( object_name, method, options.merge( :class => css_class), checked_value, unchecked_value )
      end

      alias_method :orig_text_field, :text_field

      def text_field( object_name, method, options = {} )
        css_class = "textfield"
        
        if options.include?( :class )
          css_class = options[:class] + " " + css_class
        end

        if ! options.include?( :tabindex )
          options[:tabindex] = 1
        end
        
        orig_text_field( object_name, method, options.merge( :class => css_class ) )
      end

      alias_method :orig_password_field, :password_field

      def password_field( object_name, method, options = {} )
        css_class = "textfield"
        
        if options.include?( :class )
          css_class = options[:class] + " " + css_class
        end

        if ! options.include?( :tabindex )
          options[:tabindex] = 1
        end
        
        orig_password_field( object_name, method, options.merge( :class => css_class ) )
      end


    end

    module FormTagHelper
      alias_method :orig_password_field_tag, :password_field_tag

      def password_field_tag( name="password", value=nil, options={} )
        css_class = "textfield"
        
        if options.include?( :class )
          css_class = options[:class] + " " + css_class
        end

        if ! options.include?( :tabindex )
          options[:tabindex] = 1
        end
        
          
        orig_password_field_tag( name, value, options.merge( :class => css_class) )
      end

      alias_method :orig_submit_tag, :submit_tag

      def submit_tag( value, options = {})

        if value == "Help"
          # "<span class=\"iconbutton\"><span>" +
          return link_to( "Help", HELP_URL + "?version=" + UNTANGLE_VERSION + "&source=" + HELP_NAMESPACE + "_" + $current_controller + "_" + $current_action, :popup => [ 'new_window', 'height=450,width=650,scrollbars=1,toolbar=1,status=1,location=1,menubar=1,resizeable=1' ], :class => "Help" )
          #  + "</span></span>"
        end

        result_prefix = ""
        result_suffix = ""

        css_class = "submit"

        #List of buttons with an icon:
        icon_submit = [ "Save", "Cancel" ]
       
        if icon_submit.include?( value )
          #result_prefix = result_prefix + "<span class=\"iconbutton\"><span>"
          #result_suffix = "</span></span>" + result_suffix
          css_class = css_class + " " + value
        end

        #IE6 does not support css attribute selectors
        #this impelements similar functionality server side by adding a class
        #so instead of input[type="submit"] you can use input.submit
        #for IE6 compatibility
        if options.include?( :class )
          css_class = options[:class] + " " + css_class
        end

        if ! options.include?( :tabindex )
          options[:tabindex] = 1
        end
        
        results = result_prefix + orig_submit_tag( value, options.merge( :class => css_class)) + result_suffix
      end
    end

#    module PrototypeHelper
#      module JavaScriptGenerator
#        module GeneratorMethods
#          alias_method :orig_sortable, :sortable
#          def sortable( id, options = {} )
#            if ! options.include?( :ghosting )
#              options[:ghosting] = true
#            end        
#            orig_sortable( id, options )
#          end
#        end
#      end
#    end

    module ScriptaculousHelper
      alias_method :orig_sortable_element, :sortable_element

      def sortable_element( element_id, options = {} )
        if ! options.include?( :ghosting )
          options[:ghosting] = true
        end
        orig_sortable_element( element_id, options )
      end

    end

  end
end
