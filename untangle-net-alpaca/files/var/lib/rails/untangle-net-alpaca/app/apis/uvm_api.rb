#
# $HeadURL$
# Copyright (c) 2007-2008 Untangle, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# AS-IS and WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE, TITLE, or
# NONINFRINGEMENT.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
#
class UvmApi < ActionWebService::API::Base
  inflect_names false

  ## Restart the iptables rules
  api_method :generate_rules, :expects => [], :returns => []

  ## Commit all of the iptables rules, run this at start to ensure that the uvm scripts are
  ## in /etc/untangle-net-alpaca/iptables-rules.d
  api_method :write_files, :expects => [], :returns => []

  ## Save hostname
  api_method :save_hostname, :expects => [:string, :boolean], :returns => [:boolean]

  ## Create a new session redirect
  ## Returns a unique identifier to delete the session redirect later.
  api_method :session_redirect_create, :expects => [:string, :string, :integer], :returns => [:boolean]

  ## Delete a session redirect
  api_method :session_redirect_delete, :expects => [:string, :string, :integer], :returns => [:boolean]

  ## Wizard helper routines
  api_method :wizard_start, :expects => [], :returns => []

  ## save external interface as a static address
  # @param ip
  # @param netmask
  # @param default_gateway
  # @param dns_1
  # @param dns_2
  api_method( :wizard_external_interface_static, :expects => [:string, :string, :string, :string, :string],
              :returns => [] )

  ## save external interface for Dynamic
  api_method( :wizard_external_interface_dynamic, :expects => [], :returns => [] )

  ## save external interface for PPPoE
  # @param username
  # @param password
  api_method( :wizard_external_interface_pppoe, :expects => [:string, :string], :returns => [] )

  ## save internal interface as a bridge.
  api_method( :wizard_internal_interface_bridge, :expects => [], :returns => [] )

  ## setup the internal interface for NAT.
  # @param ip
  # @param netmask
  api_method( :wizard_internal_interface_nat, :expects => [:string, :string],
              :returns => [] )

  ## Remap the interfaces
  api_method( :remap_interfaces, :expects => [[:string],[:string]], :returns => [] )
  ## Determine if the box is still alive.
  api_method( :hello_world, :expects => [], :returns => [:boolean])
end

