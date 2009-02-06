<?php

/*
 *
 *
 * --------------------------------------------------------------------
 * Copyright (c) 2001 - 2008 Openfiler Project.
 * --------------------------------------------------------------------
 *
 * Openfiler is an Open Source SAN/NAS Appliance Software Distribution
 *
 * This file is part of Openfiler.
 *
 * Openfiler is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * Openfiler is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with Openfiler.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * --------------------------------------------------------------------
 *
 *  
 */

function getUntangleNASVersion($versionQuery) {

	
	if ($versionQuery == "distro") {
	
		$distrofile = "/etc/issue";
		$dhandle = fopen($distrofile, "r");
        $nas_distro_version = fread($dhandle, filesize($distrofile));
        fclose($dhandle);
        return $nas_distro_version; 
	}
	
    else if ($versionQuery == "gui") {
	
	
        $nas_versionp = popen('/usr/bin/dpkg -s untangle-nas | /bin/grep "^Version:" | /usr/bin/cut -d ":" -f2', 'r');
        $nas_info_version = trim(fread($nas_versionp, 1024));
        pclose($nas_versionp);
        return $nas_info_version;
    }
	
}

$nas_info_version = getUntangleNASVersion("gui"); 

?>
