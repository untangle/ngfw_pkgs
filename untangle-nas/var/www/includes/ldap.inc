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

global $ldap_password;
global $ldap_server;
global $ldap_basedn;
global $ldap_rootdn;
$ldap_usersuffix="ou=People";
$ldap_groupsuffix="ou=Group";

function getvalues()
{
    global $ldap_password, $ldap_basedn, $ldap_rootdn, $ldap_tls;

    $authp = popen("export LANG=C; /usr/bin/sudo /usr/bin/rush /opt/nas/sbin/authconfig.rb --get", "r");
    while (!feof($authp))
	$aresult[] = trim(fgets($authp, 4096));
    pclose($authp);

    $ldap_password=$aresult[40];
    $ldap_server=$aresult[21];
    $ldap_basedn=$aresult[22];
    $ldap_rootdn=$aresult[39];
    
    $ldap_tls = "";
    
    if ($aresult[20] == "YES") 
        $ldap_tls = " -ZZ ";
}

function getLDAPgroup()
{
    global $ldap_password, $ldap_basedn, $ldap_rootdn, $ldap_usersuffix, $ldap_groupsuffix, $ldap_tls;
    getvalues();
    $grouparray = array();
    $memberarray = array();

    $searchstring = "objectclass=posixgroup";
    $cmd = "/usr/bin/ldapsearch $ldap_tls -x -H ldap://" . $ldap_server . " -D \"" . $ldap_rootdn . "\" -w \"$ldap_password\" -S gidNumber \"" . $searchstring . "\"";
    $groupp = popen($cmd, "r");

    while (!feof($groupp))
    {
	$line =  explode(":", fgets($groupp, 4096));
	$line[0] = trim($line[0]);
	$line[1] = trim($line[1]);

	switch ($line[0]) {
	case "dn":
	    $string = explode("cn=", $line[1]);
	    $ldap_cn = preg_replace('/,.*/', '', $string[1]);
	    break;
	case "gidNumber":
	    $ldap_gidNumber = $line[1];
	    break;
	case "memberUid":
	    $memberarray[] = $line[1];
	    break;
	case "memberUid":
	    $memberarray[] = $line[1];
	    break;
	case "objectClass":
	    if ($line[1] == "posixGroup")
		$isgroup = "true";
	    break;
	case "":
	    if ($isgroup == "true"){
		$grouparray[] = array("name" => $ldap_cn, "gid" => $ldap_gidNumber, "members" => $memberarray);
		unset($memberarray);
		$isgroup = "false";
	    }
	    break;
	}
    }

    pclose($groupp);
    return $grouparray;
}

function getLDAPuser()
{
    global $ldap_password, $ldap_basedn, $ldap_rootdn, $ldap_usersuffix, $ldap_groupsuffix, $ldap_tls;
    getvalues();
    $searchstring = "objectclass=posixaccount";
    $userarray = array();
    $userp = popen("/usr/bin/ldapsearch $ldap_tls -x -H ldap://" . $ldap_server . " -D \"" . $ldap_rootdn . "\" -w \"$ldap_password\" -b \"" . $ldap_usersuffix . "," . $ldap_basedn . "\" \"" . $searchstring . "\" uid uidNumber objectClass", "r");

    $i = 0;
    while (!feof($userp))
    {
	$line =  explode(":", fgets($userp, 4096));
	$line[0] = trim($line[0]);
	$line[1] = trim($line[1]);

	switch ($line[0]) {
	case "uid":
	    $ldap_uid  = $line[1];
	    break;
	case "uidNumber":
	    $ldap_uidNumber = $line[1];
	    break;
	case "objectClass":
	    if ($line[1] == "posixAccount")
		$isuser = "true";
	    break;
	case "":
	    if ($isuser == "true"){
		$userarray[] = array("name" => $ldap_uid, "uid" => $ldap_uidNumber);
		$isuser = "false";
	    }
	}
    }
    pclose($userp);
    return $userarray;
}

?>
