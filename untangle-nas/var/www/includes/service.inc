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
 * This file was modified by Untangle, Inc. in 2009.
 * These changes are Copyright (c) 2009 Untangle, Inc.
 *
 * --------------------------------------------------------------------
 *
 *  
 */


define('FILE_SERVICES_DESCRIPTION',
        "/opt/nas/etc/services_description.xml");
define('FILE_CLUSTER_XML', "/opt/nas/etc/cluster.xml");
define('STATE_STOPPED', 0);
define('STATE_RUNNING', 1);
define('STATE_HUNG', 2);
define('STATE_PAUSED', 3);


class ServiceManager extends XmlHandler {

    private $name = "";         // STRING: name of service
    private $daemonname = "";   // STRING: name of daemon
    private $programpath = "";  // STRING: path to service executable binary
    private $runlevels;         // ARRAY: runlevels for the service
    
    private $pidfile;           // STRING: pid file for the service process
                                // (not all processes have a pid file)                        
    private $status = 0;        // INT: current state (running/stopped/paused
    private $ppid;              // STRING: parent pid for the process
    private $pids;              // ARRAY: all pids for the process
    private $subsysfile = "";   // STRING: var/lock/subsys entry
    private $functionlist;      // ARRAY: list of functions the service supports
    private static $clustermode = false;  // BOOL: whether clustering is enabled
    private static $allrunlevels;      // ARRAY: runlevels for all services

    
    public function ServiceManager($servicename) {
        
        $this->name = $servicename;
        $this->runlevels = array();
        $this->pids = array();
        $this->functionlist = array();
        
        parent::__construct(FILE_SERVICES_DESCRIPTION);
        
        // TODO: write exception handlers
        
        
        $this->getFunctions();
        $this->getPid();
        $this->getStatus(); 
     
    }
    
    public static function getClusterMode() {
        
        if (is_file(FILE_CLUSTER_XML)) {
            
            $dom = new XmlHandler(FILE_CLUSTER_XML);
            $query = "//cluster/clustering";
            $element = $dom->runXpathQuery($query);
            $output = $element->item(0)->getAttribute("state");
            if (strcmp("on", $output) == 0)
                self::$clustermode = true;
            else
                self::$clustermode = false; 
        }
        
        return self::$clustermode; 
    }
    
    public function getDaemonName() {
        
        $query = "//services/service[@name='$this->name']/daemon";
        $runQuery = $this->runXpathQuery($query);
        $this->daemonname = $runQuery->item(0)->getAttribute("name");
        
        
        if(!empty($this->daemonname))
            return $this->daemonname;
        
        return $this->name; 
    }
    
    
    public function pause() {
        
        return $this->suspend(); 
    }
    
    
    public function suspend() {
    
        $command = "export LANG=C; /usr/bin/sudo /etc/init.d/" . $this->name . " pause";
        $response = $this->getExec($command);
        
        if ($response["ret"] != 0) {
        
            return false;    
        
        }
        
        return true;
        
    }
    
    public function resume() {
        
        $command = "export LANG=C; /usr/bin/sudo /etc/init.d/" . $this->name . " resume";
        $response = $this->getExec($command);
        
        if ($response["ret"] != 0) {
        
            return false;
            
        }
        
        return true;
        
    }
    
    public function start() {
        
        $command = "export LANG=C; /usr/bin/sudo /etc/init.d/" . $this->name . " start";
        $response = $this->getExec($command);
        
        if ($response["ret"] != 0) {
            
            //TODO : unable to start, do something about it.
            foreach (($response["output"]) as $printout) // debug
                print $printout . "<br/>"; 
            return false; 
        }
        
        foreach (($response["output"]) as $printout) // debug
            print $printout . "<br/>"; 
        return true; 
    }
    
    public function stop() {
        
        $command = "export LANG=C; /usr/bin/sudo /etc/init.d/" . $this->name . " stop";
        $response = $this->getExec($command);
        
        if ($response["ret"] != 0) {
            
            // TODO : unable to stop, do something about it.
            foreach (($response["output"]) as $printout) // debug
                print $printout . "<br/>"; 
            return false;
        }
             
        foreach (($response["output"]) as $printout) // debug
            print $printout . "<br/>"; 
        return true; 
    }
    
    public function restart() {
        
        if (in_array($this->functions, "restart")) {
            
            $command = "export LANG=C; /usr/bin/sudo /etc/init.d/" . $this->name . " restart";
            $response = $this->getExec($command);
            
            if ($response["ret"] != 0) {
                
                foreach($response["output"] as $printout) // debug
                    print $printout . "<br/>";
                return false; 
            }
        }
        
        if (!$this->stop() || !$this->start())
            return false;
            
        return true; 
    }
    
    public function reload() {
    
        if(in_array($this->functions, "reload")) {
            
            $command = "export LANG=C; /usr/bin/sudo /etc/init.d/" . $this->name . " reload";
            $response = $this->getExec($command);
            
            if ($response["ret"] != 0) {
                
                foreach ($response["output"] as $printout)
                    print($printout . "<br/>"); // debug
                return false;
            }
        }
            
        if($this->restart())
            return true;
        
        return false;
    }
    
    public function isRunning() {
        
        if($this->status == STATE_RUNNING || $this->status == STATE_PAUSED)
            return true;
        
        return false;
    }
    
    private static function getFHData($command) {
        
        $fh = popen($command . " 2>&1", "r");
        $i = 0;
        $data = array(); 
        
        while (!feof($fh))
            $data[$i++] = trim(fgets($fh, 4096));
            
        // remove EOL
        
        $EOL = array_pop($data); 
        
        pclose($fh);
        return $data;
    }
    
    private function getExec($command) {
        
        $returnData = array();
        
        exec($command, $output, $ret);
        
        $returnData["output"] = $output;
        $returnData["ret"] = $ret;
        
        return $returnData; 
    
    }
    
    public function getName() {
        
        return $this->name;
    }
    
    
    public function getPidFile() {
        
        $query = "//service[@name = '$this->name']/pidfile";
        if ($queryNode = $this->runXpathQuery($query))
            $this->pidfile = $queryNode->item(0)->getAttribute("path");
    
        return $this->pidfile;    
    }
    
    public function getStatus() {
    
        $cmd = "export LANG=C; /opt/nas/sbin/service-status " . $this->name;  
        $output = $this->getFHData($cmd);
        
        foreach($output as $line) {
            
            if (preg_match("/running/", $line)) {
                
                /* all your base are belong to us */
                
                $this->status = STATE_RUNNING;
                
                /* at least one component of the service is running
                   we now need to know whether other components of the
                   service have b0rked or if it is paused -- so continue
                   to the next loop item */
                
                continue;
               
            }
            
            if (preg_match("/paused/", $line)) {
                
                if ($this->status == STATE_RUNNING) {
                    $this->status = STATE_PAUSED;
                    break;   
                }
                
                /* hmm, we're paused but not running?
                  TODO: might want to combine this with the check for
                 "running" above */
            }
            
            if (preg_match("/but pid file exists/", $line) ||
                preg_match("/subsys locked/", $line)) {
                
                /* somebody set us up the bomb */
                
                $this->status = STATE_HUNG;
                
                /* game over, break out and return */
                
                break;
            }
            
            if (preg_match("/stopped/", $line)) {
                
                /* make your time */
                
                $this->status = STATE_STOPPED;
                
                /* game over, break out and return */
                
                break;
            }
            
        }
        
        return $this->status;    
    }
    
    public function getPpid() {
        
        return $this->ppid;
    }
    
    public function getPids() {
    
        return $this->pids;    
    }
    
    public function getSubsysFile() {
    
        return $this->subsysfile;    
    }

    public function getPid() {
    
        return $this->ppid;     
    }
    
    
    public function getFunctions() {
        
        $query = "//services/service[@name = '$this->name']";
        $serviceExists = $this->runXpathQuery($query);
        $query = "//services/service[@name = '$this->name']/function";
        $serviceFunctions = $this->runXpathQuery($query);
        
               
        if ($serviceExists->length == 0 || $serviceFunctions->length == 0) {
            
            return false;
        }
        
        for ($i = 0; $i < $serviceFunctions->length; $i++) {
            $this->functionlist[] =
                   $serviceFunctions->item($i)->getAttribute("name"); 
        }
    
        //print_r($this->functionlist); //debug
        //print "<br/>"; //debug
        return $this->functionlist; 
    }
    
}



?>
