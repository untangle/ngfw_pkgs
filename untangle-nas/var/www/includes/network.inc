<?php


/*
 * --------------------------------------------------------------------
 * Copyright (c) Nathan Jones (najones AT vt.edu)
 * --------------------------------------------------------------------
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


/*
 * Provides necessary classes and functions for handling and manulating network
 * configurations
 *
 */

define('FILE_NETWORKHOSTS', "/opt/nas/etc/networks.xml");
define('FILE_RESOLV', "/etc/resolv.conf");
define('FILE_HOSTS', "/etc/hosts");
define('FILE_MODPROBE', "/etc/modprobe.conf");
define('CMD_ETHTOOL', "export LANG=C; /usr/bin/sudo /sbin/ethtool 2>&1 ");
define('CMD_MIITOOL', "export LANG=C; /usr/bin/sudo /sbin/mii-tool 2>&1 ");
define('CMD_IFCONFIG', "export LANG=C; /usr/bin/sudo /sbin/ifconfig 2>&1 ");
define('CMD_VCONFIG', "export LANG=C; /usr/bin/sudo /sbin/vconfig 2>&1 ");
define('CMD_IFUP', "export LANG=C; /usr/bin/sudo /sbin/ifup 2>&1 ");
define('CMD_IFDOWN', "export LANG=C; /usr/bin/sudo /sbin/ifdown 2>&1 ");
define('CMD_HOSTNAME', "export LANG=C; /usr/bin/sudo /bin/hostname 2>&1 ");


Class Network {
	var $devices = array();
	var $bonds = array();
	var $vinterfaces = array();
	var $vlans = array();

	function Network() {
		//Network constructor
		$this->GetNICs();
		return 0;
	}

	function ListDevices() {
	        $list = array_merge($this->ListNICs());
		sort($list);
		return $list;
		
	}

	function ListNICs() {
		return $this->devices;
	}

	function GetNICs() {
		exec("sudo /bin/grep \"eth\" /var/log/dmesg",$output);
		foreach ($output as $line){
			if (preg_match("/eth[0-9][0-9]*/i", $line, $match))
				$this->devices[] = $match[0];
		}
		
		$this->devices = array_unique($this->devices);
		sort($this->devices);
	}

	function GetDNS() {
		$file = new File(FILE_RESOLV);
		if(!$file->Load())
			return false; //couldn't open file

		$entries = array();
		$needle = "nameserver ";
		while (!$file->EOF()){
			if (preg_match("/" . $needle . "[^ ][^ ]*/i", $file->GetLine(), $match)){
				$entries[] = trim(preg_replace("/" . $needle ."/i", "", $match[0]));
			}
		}
		return $entries;
	}

	function SetDNS($dns1, $dns2) {
		$file = new File(FILE_RESOLV);

		$file->AddLine("search " . $this->GetHostname());
		if ($dns1)
			$file->AddLine("nameserver " . $dns1);
		if ($dns2)
			$file->AddLine("nameserver " . $dns2);
		$file->Save();
	}

	function GetHostname() {
		exec(CMD_HOSTNAME, $output, $retval);
		$output = implode(" ", $output);
		if ($retval)
			$error = $output; //capturuing error for future development
		return $output;
	}

	function GetDomain() {
		exec(CMD_HOSTNAME . " -d", $output, $retval);
		$output = implode(" ", $output);
		if ($retval)
			$error = $output; //capturuing error for future development
		return $output;
	}


	function Restart() {
		exec("export LANG=C; /usr/bin/sudo /etc/init.d/network restart 2>&1", $output, $retval);
		if ($retval) //error occured
			$error = implode(" ", $output); //future
		return $retval;
	}

	function IsValidIP($ip) { 
		if (preg_match("/^[0-9]{1,3}(.[0-9]{1,3}){3}$/",$ip)) {
			foreach(explode(".", $ip) as $octet) {
				if ($octet<1 || $octet>255)
					return false;
			}
		}
		else
			return false;
		return true;
	}

	//this function is to generate all the possible netmasks
	function GenerateNetmasks() {
		$values = array();
		for ($i = 31; $i >= 0; $i--) {
			$values[] = (long2ip($intmask));
			$intmask += intval(pow(2, $i));
		}
		$values[] = long2ip(pow(2, 32) - 1);
		return $values;
	}
}



class NetworkAccessList {
	var $xpath;
	var $domfile;

	function NetworkAccessList(){
		$this->Load();
		if(!$this->domfile->haschildnodes()) {//look for nodes, if none found, make nodes
			$this->Save();

			$file = new File(FILE_NETWORKHOSTS);
			$file->Load();
			$file->AddLine("<networks>");
			$file->AddLine("</networks>");
			$file->Save();

			$this->Load(); //file changed, reload
		}

		return true;
	}

	function Load(){
		$this->domfile = new DOMDocument;
		$this->dom->ValidateOnParse = true;
		$this->domfile->load(FILE_NETWORKHOSTS);
		$this->xpath = new DOMXpath($this->domfile);
	}

	function ListItems()
	{
		$query = "//network";
		$nodelist = $this->xpath->query($query);

		$nodearray = array();
		foreach ($nodelist as $node)
			$nodearray[]=array("name"=>$node->getAttribute("name"), "network"=>$node->getAttribute("network"),
				"netmask"=>$node->getAttribute("netmask"), "type"=>$node->getAttribute("type"));
		return $nodearray;
	}

	function AddItem($name, $network, $netmask, $type)
	{
		if (!$this->GetItem($name)){
			$entry = $this->domfile->createElement('network');
			$entry->setAttribute("name", $name);
			$entry->setAttribute("network", $network);
			$entry->setAttribute("netmask", $netmask);
			$entry->setAttribute("type", $type);

			$this->domfile->firstChild->appendChild($entry);
			return true;
		}
		return false;
	}

	function RemoveItem($name)
	{
		$query = "//network[@name='$name']";
		$nodelist = $this->xpath->query($query);
		$this->domfile->documentElement->removeChild($nodelist->item(0));
		return true;
	}

	function Save()
	{
		$this->domfile->save(FILE_NETWORKHOSTS);

		return true;
	}

	function GetItem($name)
	{
		$query = "//network[@name='$name']";
		$nodelist = $this->xpath->query($query);
		foreach ($nodelist as $node){
			return array("name"=>$node->getAttribute("name"),
				"network"=>$node->getAttribute("network"),
				"netmask"=>$node->getAttribute("netmask"),
				"type"=>$node->getAttribute("type"));
		}
		return false;
	}
}
?>
