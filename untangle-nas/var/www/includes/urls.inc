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



    $C_VOLUME_GROUP_MANAGEMENT =  array("li_class"=>"volumes_group", "title"=>"Volume Groups","url"=>"/nas/admin/volumes_vgmanage.html");
    $C_VOLUME_PHYSICAL_MANAGEMENT = array("li_class"=>"volumes_physical","title"=>"Block Devices","url"=>"/nas/admin/volumes_physical.html");
    $C_VOLUME_CREATE = array("li_class"=>"volumes_create","title"=>"Add Volume","url"=>"/nas/admin/volumes_create.html");
    $C_VOLUME_ISCSI_TARGETS = array("li_class"=>"volumes_iscsi","title"=>"iSCSI Targets", "url"=>"/nas/admin/volumes_iscsi_targets.html");
    $C_VOLUME_RAID_MANAGE = array("li_class"=>"volumes_raid","title"=>"Software RAID","url"=>"/nas/admin/volumes_raidmanage.html");
    $C_VOLUME_EXISTING = array("li_class"=>"volumes_logical","title"=>"Manage Volumes","url"=>"/nas/admin/volumes.html");


    $C_ACCOUNTS = array("li_class"=>"accounts_accounts","title"=>"Authentication", "url"=>"/nas/admin/");

    $C_QUOTA = array("li_class"=>"quota_group","title"=>"Group Quota", "url"=>"/nas/admin/quota.html");
    $C_QUOTA_USER = array("li_class"=>"quota_user","title"=>"User Quota", "url"=>"/nas/admin/quota_user.html");
    $C_QUOTA_GUEST = array("li_class"=>"quota_guest","title"=>"Guest Quota", "url"=>"/nas/admin/quota_guest.html");
    
    
    $C_SHARES = array("li_class"=>"shares_existing","title"=>"Existing Shares", "url"=>"/nas/admin/shares.html");
    $C_SHARES_SNAPSHOTS = array("li_class"=>"shares_snapshot","title"=>"Snapshot Shares", "url"=>"/nas/admin/shares_snapshots.html");
   
    $C_SERVICES = array("li_class"=>"services_enable_disable","title"=>"Manage Services", "url"=>"/nas/admin/services.html");
    $C_SERVICES_SMB = array("li_class"=>"services_smb","title"=>"SMB/CIFS Setup", "url"=>"/nas/admin/services_smb.html");
    $C_SERVICES_UPS = array("li_class"=>"services_ups","title"=>"UPS Setup", "url"=>"/nas/admin/services_ups.html");
    $C_SERVICES_ISCSI_TARGET = array("li_class"=>"services_iscsi","title"=>"iSCSI Target Setup", "url"=>"/nas/admin/services_iscsi_target.html");
    $C_SERVICES_RSYNC = array("li_class"=>"services_rsync","title"=>"Rsync Setup","url"=>"/nas/admin/services_rsync.html");
    $C_SERVICES_FTP = array("li_class"=>"services_ftp", "title"=>"FTP Setup", "url"=>"/nas/admin/services_ftp.html"); 
  
    $C_STATUS = array("li_class"=>"status_system_overview","title"=>"System Overview", "url"=>"/nas/admin/status.html");
    $C_STATUS_ISCSI = array("title"=>"iSCSI Targets", "url"=>"/nas/admin/status_iscsi.html");

    $C_GENERAL = array("li_class"=>"system_network","title"=>"Network Setup", "url"=>"/nas/admin/system.html");
    $C_GENERAL_AUTHENTICATION = array("li_class"=>"system_authentication","title"=>"Authentication", "url"=>"/nas/admin/index.html");
    $C_GENERAL_UPS = array("li_class"=>"system_ups","title"=>"UPS Management", "url"=>"/nas/admin/system_ups.html");
    $C_GENERAL_SHUTDOWN = array("li_class"=>"system_shutdown","title"=>"Shutdown/Reboot", "url"=>"/nas/admin/system_shutdown.html");
    $C_GENERAL_NOTIFICATION = array("li_class"=>"system_notification","title"=>"Notification", "url"=>"/nas/admin/system_info.html");

    $P_GENERAL_CHILDREN = array("C_GENERAL"=>$C_GENERAL, 
#                                "C_GENERAL_AUTHENTICATION"=>$C_GENERAL_AUTHENTICATION, 
#                                "C_GENERAL_UPS"=>$C_GENERAL_UPS, 
                                "C_GENERAL_SHUTDOWN"=>$C_GENERAL_SHUTDOWN, 
                                "C_GENERAL_NOTIFICATION"=>$C_GENERAL_NOTIFICATION);

    $P_STATUS_CHILDREN = array("C_STATUS"=>$C_STATUS
# , "C_STATUS_ISCSI"=>$C_STATUS_ISCSI
			       );

  
    $P_SERVICES_CHILDREN = array("C_SERVICES"=>$C_SERVICES,
                                 "C_SERVICES_SMB"=>$C_SERVICES_SMB, 
                                 "C_SERVICES_UPS"=>$C_SERVICES_UPS,
                                 "C_SERVICES_RSYNC"=>$C_SERVICES_RSYNC,
                                 "C_SERVICES_ISCSI_TARGET"=>$C_SERVICES_ISCSI_TARGET,
                                 "C_SERVICES_FTP"=>$C_SERVICES_FTP);
   
    $P_SHARES_CHILDREN = array("C_SHARES"=>$C_SHARES, 
                               "C_SHARES_SNAPSHOTS"=>$C_SHARES_SNAPSHOTS);

    
    $P_QUOTA_CHILDREN = array("C_QUOTA"=>$C_QUOTA, 
                              "C_QUOTA_USER"=>$C_QUOTA_USER, 
                              "C_QUOTA_GUEST"=>$C_QUOTA_GUEST); 
    


    $P_VOLUMES_CHILDREN = array("C_VOLUME_EXISTING"=>$C_VOLUME_EXISTING,
                                "C_VOLUME_GROUP_MANAGEMENT"=>$C_VOLUME_GROUP_MANAGEMENT, 
                                "C_VOLUME_PHYSICAL_MANAGEMENT"=>$C_VOLUME_PHYSICAL_MANAGEMENT, 
                                "C_VOLUME_CREATE"=>$C_VOLUME_CREATE,
#                                "C_VOLUME_ISCSI_TARGETS"=>$C_VOLUME_ISCSI_TARGETS,
                                "C_VOLUME_RAID_MANAGE"=>$C_VOLUME_RAID_MANAGE);


    $P_VOLUMES = array("li_class"=>"volumes", "title"=>"Volumes","url"=>"/nas/admin/volumes.html","children"=>$P_VOLUMES_CHILDREN);
    $P_QUOTA = array("li_class"=>"quota","title"=>"Quota","url"=>"/nas/admin/quota.html", "children"=>$P_QUOTA_CHILDREN);
    $P_SHARES = array("li_class"=>"shares","title"=>"Shares","url"=>"/nas/admin/shares.html", "children"=>$P_SHARES_CHILDREN);
    $P_SERVICES = array("li_class"=>"services","title"=>"Services","url"=>"/nas/admin/services.html", "children"=>$P_SERVICES_CHILDREN); 
    $P_STATUS = array("li_class"=>"status","title"=>"Status","url"=>"/nas/admin/status.html", "children"=>$P_STATUS_CHILDREN);
    $P_GENERAL = array("li_class"=>"system", "title"=>"System","url"=>"/nas/admin/system.html", "children"=>$P_GENERAL_CHILDREN);


    $T_URLS = array("P_STATUS"=>$P_STATUS, 
                    "P_GENERAL"=>$P_GENERAL, 
                    "P_VOLUMES"=>$P_VOLUMES, 
                    "P_QUOTA"=>$P_QUOTA, 
                    "P_SHARES"=>$P_SHARES);
    

    function getParentTab($childKey) {
        global $T_URLS;
        foreach($T_URLS as $key => $value) {
            foreach($value as $key2 => $value2) {
                if(is_array($value2)) {
                    foreach($value2 as $key3 => $value3) {
                        if($key3 == $childKey) {
                                return array($key => $value);
                        }
                    }    
                }
            }
        }
    }

    function getTabs($tabs) {
    
        global $T_URLS;
        if (array_key_exists($tabs,  $T_URLS)) {
                $parentTab = array($tabs => $T_URLS[$tabs]);
        //we're a parent tab 
        }

        else {
                $parentTab = getParentTab($tabs);
        // we're a child tab
        }

        return $parentTab; 
            
    }

?>
