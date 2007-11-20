# Loads mkmf which is used to make makefiles for Ruby extensions
require 'mkmf'

# Give it a name
extension_name = 'pam_auth'

# The destination
dir_config( extension_name )

# Need the pam library in order to run
have_library( "pam","pam_start" )

# Do the work
create_makefile( extension_name )
