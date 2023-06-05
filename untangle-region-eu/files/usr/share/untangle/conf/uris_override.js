{
    "dnsTestHost": "updates.untangle.com",
    "javaClass": "com.untangle.uvm.UriManagerSettings",
    "tcpTestHost": "updates.untangle.com",
    "uriTranslations": {
        "javaClass": "java.util.LinkedList",
        "list": [
            {
                "javaClass": "com.untangle.uvm.UriTranslation",
                "uri": "https://ids.untangle.com/suricatasignatures.tar.gz" // no valid edge.arista address
            },
            {
                "javaClass": "com.untangle.uvm.UriTranslation",
                "uri": "https://labs.untangle.com/Utility/v1/mac" // no valid edge.arista address
            },
            {
                "javaClass": "com.untangle.uvm.UriTranslation",
                "uri": "https://auth-relay.untangle.com/callback.php" // no valid edge.arista address
            },
            {
                "javaClass": "com.untangle.uvm.UriTranslation",
                "uri": "https://auth.untangle.com/v1/CheckTokenAccess" // no valid edge.arista address
            },
            {
                "javaClass": "com.untangle.uvm.UriTranslation",
                "uri": "https://telemetry.untangle.com/ngfw/v1/infection" // no valid edge.arista address
            },
            {
                "javaClass": "com.untangle.uvm.UriTranslation",
                "uri": "http://updates.untangle.com/" // no valid edge.arista address
            },
            {
                "javaClass": "com.untangle.uvm.UriTranslation",
                "uri": "https://launchpad.edge.arista.com",
                "host": "eu.edge.arista.com" // is this valid? launchpad.eu.edge.arista.com doesn't exist
            },
            {
                "javaClass": "com.untangle.uvm.UriTranslation",
                "uri": "https://license.untangle.com/license.php" // no valid edge.arista address (note: this def won't be changed, license not yet available)
            },
            {
                "javaClass": "com.untangle.uvm.UriTranslation",
                "uri": "https://classify.untangle.com/v1/md5s" // no valid edge.arista address
            },
            {
                "javaClass": "com.untangle.uvm.UriTranslation",
                "uri": "https://edge.arista.com/ng-firewall/free-trial" // resolved to this. Correct address?
            },
            {
                "javaClass": "com.untangle.uvm.UriTranslation",
                "uri": "https://boxbackup.untangle.com/boxbackup/backup.php", // no valid edge.arista address
                "host": "boxbackup-eu.untangle.com"
            },
            {
                "javaClass": "com.untangle.uvm.UriTranslation",
                "uri": "https://boxbackup.untangle.com/api/index.php", // no valid edge.arista address
                "host": "boxbackup-eu.untangle.com"
            },
            {
                "javaClass": "com.untangle.uvm.UriTranslation",
                "uri": "https://downloads.untangle.com/download.php" // no valid edge.arista address
            },
            {
                "javaClass": "com.untangle.uvm.UriTranslation",
                "uri": "http://translations.untangle.com/" // no valid edge.arista address
            },
            {
                "javaClass": "com.untangle.uvm.UriTranslation",
                "uri": "https://queue.untangle.com/", // no valid edge.arista address
                "host": "queue-eu.untangle.com"
            },
            {
                "javaClass": "com.untangle.uvm.UriTranslation",
                "uri": "https://edge.arista.com/api/v1/appliance/OnSettingsUpdate",
                "host": "eu.edge.arista.com"
            },
            {
                "javaClass": "com.untangle.uvm.UriTranslation",
                "uri": "https://supssh.untangle.com/" // untangle address doesn't resolve, AND no valid edge.arista address
            },
            {
                "javaClass": "com.untangle.uvm.UriTranslation",
                "uri": "https://sshrelay.untangle.com/", // no valid edge.arista address
                "host": "sshrelay-eu.untangle.com"
            },
            {
                "javaClass": "com.untangle.uvm.UriTranslation",
                "uri": "https://www.edge.arista.com/api/v1",
                "host": "eu.edge.arista.com"
            },
            {
                "javaClass": "com.untangle.uvm.UriTranslation",
                "uri": "https://launchpad.edge.arista.com/",
                "host": "eu.edge.arista.com"
            }
        ]
    },
    "version": 3
}
