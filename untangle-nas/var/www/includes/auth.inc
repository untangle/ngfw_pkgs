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

if (isset($GLOBALS["authenticated"]))
	unset($GLOBALS["authenticated"]);

if (isset($GLOBALS["authuser"]))
	unset($GLOBALS["authuser"]);

function is_valid_foldername($foldername)
{
	if ((strlen($foldername) > 0) && (!strstr($foldername, '/')) && ($foldername != ".") && ($foldername != ".."))
		return true;
	else
		return false;
}

function is_valid_user($username)
{
	return true;
}

function is_valid_group($groupname)
{
	if (strspn($groupname, "abcdefghijklmnopqrstuvwxyz0123456789") == strlen($groupname))
		return true;
	else
		return false;
}

function check_authenticated($username, $password)
{
	return true;
}

function makehash($password)
{
	return md5($password);
}

function show_account_details($params)
{
	print("<div style=\"text-align: center;\" ><p>Welcome Administrator! <br/>You can <a href=\"/nas/admin/status.html\">administer the storage device from here.</a></p>\n");
	print("<p><a href=\"/nas/account/logout.html\">Log out</a>.</p></div>\n");
}

