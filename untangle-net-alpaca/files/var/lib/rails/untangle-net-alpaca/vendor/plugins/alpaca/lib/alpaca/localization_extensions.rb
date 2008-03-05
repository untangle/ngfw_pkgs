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
module Alpaca::LocalizationExtension
  ## These are straight from globalze, just replacements to transition to gettext.

  def translate(default = nil, arg = nil, namespace = nil)
    ## no translation occurring here.
    return self if arg.nil?
    
    ## format the string with printf.
    return sprintf( self, *arg )
  end

  alias :t :translate
  
  # Translates the string into the active language using the supplied namespace.
  #
  # Example:
  #          <tt>"draw".t -> "dibujar"</tt>
  #          <tt>"draw".tn(:lottery) -> "seleccionar"</tt>
  def translate_with_namespace(namespace, arg = nil, default = nil)
    translate( default, arg, namespace )
  end
  
  alias :tn :translate_with_namespace
  
  # Translates the string into the active language using the supplied namespace.
  # This is equivalent to translate_with_namespace(arg).
  #
  # Example:
  #          <tt>"draw".t -> "dibujar"</tt>
  #          <tt>"draw" >> 'lottery' -> "seleccionar"</tt>
  def >>(namespace)
    translate_with_namespace(namespace, nil, nil)
  end
  
  # Translates the string into the active language. This is equivalent
  # to translate(arg).
  #
  # Example: <tt>"There are %d items in your cart" / 1 -> "There is one item in your cart"</tt>
  def /(arg)
    translate(nil, arg)
  end
end

class ::String # :nodoc: 
  include Alpaca::LocalizationExtension
end

