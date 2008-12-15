require 'yaml'
require 'strscan'

module ActiveSupport
  module JSON
    class ParseError < StandardError
    end
    
    class << self
      # Converts a JSON string into a Ruby object.
      def decode(json)
        YAML.load(convert_json_to_yaml(json))
      rescue ArgumentError => e
        raise ParseError, "Invalid JSON string"
      end
      
      protected
        # matches YAML-formatted dates
        DATE_REGEX = /^\d{4}-\d{2}-\d{2}|\d{4}-\d{1,2}-\d{1,2}[ \t]+\d{1,2}:\d{2}:\d{2}(\.[0-9]*)?(([ \t]*)Z|[-+]\d{2}?(:\d{2})?)?$/

        # Ensure that ":" and "," are always followed by a space
        def convert_json_to_yaml(json) #:nodoc:
          scanner, quoting, marks, pos, times = StringScanner.new(json), false, [], nil, []
          while scanner.scan_until(/(\\['"]|['":,\\]|\\.)/)
            case char = scanner[1]
            when '"', "'"
              if !quoting
                quoting = char
                pos = scanner.pos
              elsif quoting == char
                if json[pos..scanner.pos-2] =~ DATE_REGEX
                  # found a date, track the exact positions of the quotes so we can remove them later.
                  # oh, and increment them for each current mark, each one is an extra padded space that bumps
                  # the position in the final YAML output
                  total_marks = marks.size
                  times << pos+total_marks << scanner.pos+total_marks
                end
                quoting = false
              end
            when ":",","
              marks << scanner.pos - 1 unless quoting
            end
          end

          if marks.empty?
            json.gsub(/\\\//, '/')
          else
            left_pos  = [-1].push(*marks)
            right_pos = marks << json.length
            output    = []
            left_pos.each_with_index do |left, i|
              output << json[left.succ..right_pos[i]]
            end
            output = output * " "
            
            times.each { |i| output[i-1] = ' ' }
            output.gsub!(/\\\//, '/')
            output
          end
        end
    end
  end
end

module ActionController
  # Handles JSON requests.
  module JsonRequest
    def self.included(mod)
      mod.param_parsers[Mime::JSON] = lambda { |body| { :_json => ActiveSupport::JSON.decode(body) }.with_indifferent_access }
      mod.extend ClassMethods
      mod.json_request
    end

  private

    def rename_json_params(name = nil) #:nodoc:
      if data = params.delete(:_json)
        name ||= controller_name
        name = name.to_s.singularize unless data.is_a?(Array)
        params.update(name=>data)
      end
    end

    module ClassMethods

      # Use this to handle JSON requests.  Adds a MIME handler for requests with the content type +application/json+,
      # and maps an incoming request to the proper parameter.
      #
      # All controllers inherit this bahavior using the controller name to determine the parameter name.  For example,
      # the ItemsController will store the JSON request in the parameter 'item'.
      #
      # You can also configure this as a filter and specify a specific parameter name, for example:
      #   class FooController < ActionController::Base
      #     json_request :bar, :only=>[:update]
      #   end
      def json_request(*args)
        options = args.last.is_a?(::Hash) ? args.pop : {}
        prepend_before_filter(options) { |controller| controller.send :rename_json_params, args.first }
      end

    end
  end
end 

