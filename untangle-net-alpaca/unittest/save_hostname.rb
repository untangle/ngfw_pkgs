
require "alpaca_context"

hostname_controller = $alpaca_context.hostname
hostname_settings = hostname_controller.get_settings

puts "hostname is currently: #{hostname_settings["hostname_settings"]["hostname"]}"
hostname_settings["hostname_settings"]["hostname"] = ARGV[0]

hostname_controller.set_settings( hostname_settings )

hostname_settings = hostname_controller.get_settings

puts "hostname is now: #{hostname_settings["hostname_settings"]["hostname"]}"


