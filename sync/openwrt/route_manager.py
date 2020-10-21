"""route_manager manages wan based routing decisions"""
# pylint: disable=unused-argument
# pylint: disable=no-self-use
# pylint: disable=too-many-statements
# pylint: disable=line-too-long
# pylint: disable=too-many-branches
# pylint: disable=too-many-locals
import os
import stat
import traceback
from sync import registrar, Manager
from sync import nftables_util
from sync import network_util
from sync import Variables

# This class is responsible for writing /etc/iproute2/rt_tables and /etc/hotplug.d/iface/*
# based on the settings object passed from sync-settings


class RouteManager(Manager):
    """Manages files responsible for wan routing"""

    SRC_INTERFACE_MASK_INVERSE = 0xffffff00
    SRC_INTERFACE_SHIFT = 0
    CLIENT_INTERFACE_MASK = 0x000000ff
    CLIENT_INTERFACE_MASK_INVERSE = 0xffffff00
    CLIENT_INTERFACE_SHIFT = 0
    SERVER_INTERFACE_MASK = 0x0000ff00
    SERVER_INTERFACE_MASK_INVERSE = 0xffff00ff
    SERVER_INTERFACE_SHIFT = 8
    SRC_TYPE_MASK = 0x03000000
    SRC_TYPE_MASK_INVERSE = 0xfcffffff
    SRC_TYPE_SHIFT = 24
    CLIENT_TYPE_MASK = 0x03000000
    CLIENT_TYPE_MASK_INVERSE = 0xfcffffff
    CLIENT_TYPE_SHIFT = 24
    SERVER_TYPE_MASK_INVERSE = 0xf3ffffff
    SERVER_TYPE_SHIFT = 26
    ALL_MASK = 0x0f00ffff
    LOCAL_INTERFACE_ID = 0xff #255

    rt_tables_filename = "/etc/iproute2/rt_tables"
    rt_tables_file = None
    ifup_routes_filename = "/etc/config/ifup.d/10-default-route"
    ifup_route_file = None
    ifdown_routes_filename = "/etc/config/ifdown.d/10-default-route"
    ifdown_route_file = None
    wan_routing_filename = "/etc/config/nftables-rules.d/102-wan-routing"
    wan_routing_file = None
    wan_manager_filename = "/etc/config/wan_manager"
    wan_manager_file = None

    def initialize(self):
        """initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.ifup_routes_filename, "restart-default-route", self)
        registrar.register_file(self.ifdown_routes_filename, "restart-default-route", self)
        registrar.register_file(self.rt_tables_filename, "restart-networking", self)
        registrar.register_file(self.wan_routing_filename, "restart-wan-routing", self)
        registrar.register_file(self.wan_manager_filename, "restart-wan-routing", self)

    def sanitize_settings(self, settings_file):
        """sanitizes settings"""
        settings = settings_file.settings
        wan = settings['wan']
        nftables_util.create_id_seq(wan, wan.get('policies'), 'policyIdSeq', 'policyId')

        for chain in wan.get('policy_chains'):
            nftables_util.create_id_seq(chain, chain.get('rules'), 'ruleIdSeq', 'ruleId')
            nftables_util.clean_rule_actions(chain, chain.get('rules'))


        #Clean up rules and policies that may be referencing a disabled interface, only if Force is passed as true
        force = bool(Variables.get('force'))

        if force == True:
            policies = wan.get('policies')
            for pidx, policy in enumerate(policies):
                interfaces = policy.get('interfaces')
                for iidx, interface in enumerate(interfaces):
                    curr_intf = network_util.get_interface_by_id(settings, interface.get('interfaceId'));
                    if policy.get("enabled") and interface.get('interfaceId') != 0 and (curr_intf is None or curr_intf.get('enabled') == False):
                        print("WARNING: Disabling policy: %s because the related interface (Id: %s) is disabled or removed." % (policy.get('description'), interface.get('interfaceId')))
                        policies[pidx]['enabled'] = False

            policy_chains = wan.get("policy_chains")
            for pcidx, policy_chain in enumerate(policy_chains):
                for ridx, rule in enumerate(policy_chain.get("rules")):
                    action = rule.get("action")
                    if action.get("type") == "WAN_POLICY":
                        policy = action.get("policy")
                        curr_pol = network_util.get_policy_by_id(settings, policy)
                        if rule.get("enabled") and (curr_pol is None or curr_pol.get('enabled') == False):
                            print("WARNING: Disabling rule: %s because the related policy (Id: %s) is disabled or removed." % (rule.get('description'), policy))
                            policy_chain.get("rules")[ridx]['enabled'] = False


    def validate_settings(self, settings_file):
        """validates settings"""
        settings = settings_file.settings
        wan = settings['wan']
        policies = wan.get('policies')
        policy_ids = []
        invalidRPs = []

        for policy in policies:
            interfaces = policy.get('interfaces')
            policy_id = policy.get('policyId')
            if policy_id is None:
                raise Exception("Policy missing policyId")
            if policy_id in policy_ids:
                raise Exception("Duplicate policyId " + str(policy_id))
            policy_ids.append(policy_id)
            if interfaces is None:
                raise Exception("No interfaces specified: policy " + str(policy_id))

            for interface in interfaces:
                if interface.get('interfaceId') is None:
                    raise Exception("No interface id specified: policy " + str(policy_id))

                weight = interface.get('weight')
                if weight is not None and (weight > 10000 or weight < 1):
                    raise Exception("Invalid interface weight specified: policy " + str(policy_id) + " " + str(weight))

                curr_intf = network_util.get_interface_by_id(settings, interface.get('interfaceId'));
                if policy.get("enabled") and interface.get('interfaceId') != 0 and (curr_intf is None or curr_intf.get('enabled') == False):
                    invalidRPs.append("CONFIRM: Wan Rule Policy '%s' references a deleted or disabled interface: '%s'." %  (policy.get('description'), interface.get('interfaceId')))

        policy_chains = wan.get("policy_chains")
        if policy_chains is None:
            raise Exception("Missing policy_chains in WAN settings")
        for policy_chain in policy_chains:
            if policy_chain.get("rules") is None:
                raise Exception("Missing rules in wan settings policy chain.")
            for rule in policy_chain.get("rules"):
                action = rule.get("action")
                rule_id = rule.get("ruleId")
                if rule_id is None:
                    raise Exception("Missing ruleId in WAN rule")
                if action is None:
                    raise Exception("Missing action in WAN rule" + str(rule_id))
                if rule.get("enabled") is None:
                    raise Exception("Missing enabled in WAN rule" + str(rule_id))
                if action.get("type") is None:
                    raise Exception("Missing action type in WAN rule" + str(rule_id))
                if action.get("type") == "WAN_POLICY":
                    policy = action.get("policy")
                    if policy not in policy_ids:
                        raise Exception("WAN rule " + str(rule_id) + " uses missing WAN policy " + str(policy))

                    curr_pol = network_util.get_policy_by_id(settings, policy)
                    if rule.get("enabled") and (curr_pol is None or curr_pol.get('enabled') == False):
                        invalidRPs.append("CONFIRM: Rule Description: '%s' references a deleted or disabled policy: '%s'." %  (rule.get('description'), policy))        
        
        if invalidRPs is not None and len(invalidRPs) > 0:
            str1 = "\n"
            raise Exception(str1.join(invalidRPs))


    def create_settings(self, settings_file, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)

        wans = []
        interfaces = settings_file.settings.get('network').get('interfaces')
        for intf in interfaces:
            if enabled_wan(intf):
                wans.append(intf.get('interfaceId'))

        settings_file.settings['wan'] = {}
        settings_file.settings['wan']['policy_chains'] = [
            {
                "default": True,
                "description": "User defined wan routing rules",
                "name": "user-wan-rules",
                "rules": [
                    {
                        "action": {
                            "policy": 1,
                            "type": "WAN_POLICY"
                        },
                        "conditions": [],
                        "description": "Send all traffic to wan policy 1",
                        "enabled": True,
                        "ruleId": 1
                    }
                ]
            }
        ]

        settings_file.settings['wan']['policies'] = [{
            "best_of_metric": "LOWEST_LATENCY",
            "criteria": [],
            "description": "Lowest Latency WAN",
            "enabled": True,
            "interfaces": [
                {
                    "interfaceId": 0
                }
            ],
            "type": "BEST_OF",
            "policyId": 1
        }, {
            "best_of_metric": "HIGHEST_AVAILABLE_BANDWIDTH",
            "criteria": [],
            "description": "Highest Bandwidth WAN",
            "enabled": True,
            "interfaces": [
                {
                    "interfaceId": 0
                }
            ],
            "type": "BEST_OF",
            "policyId": 2
        }, {
            "balance_algorithm": "AVAILABLE_BANDWIDTH",
            "criteria": [],
            "description": "Balance by Bandwidth Available",
            "enabled": True,
            "interfaces": [
                {
                    "interfaceId": 0
                }
            ],
            "type": "BALANCE",
            "policyId": 3
        }, {
            "balance_algorithm": "BANDWIDTH",
            "criteria": [],
            "description": "Balance by Bandwidth",
            "enabled": True,
            "interfaces": [
                {
                    "interfaceId": 0
                }
            ],
            "type": "BALANCE",
            "policyId": 4
        }]

    def sync_settings(self, settings_file, prefix, delete_list):
        """syncs settings"""
        print("%s: Syncing settings" % self.__class__.__name__)
        self.write_rt_tables_file(settings_file.settings, prefix)
        self.write_ifup_routes_file(settings_file.settings, prefix)
        self.write_ifdown_routes_file(settings_file.settings, prefix)
        self.write_wan_routing_file(settings_file.settings, prefix)
        self.write_wan_manager_file(settings_file.settings, prefix)

        # the first go at wan routing support created these files, but
        # we don't need them anymore.  Eventually this can be removed
        delete_list.append("/etc/config/ifup.d/20-wan-balancer")
        delete_list.append("/etc/config/ifdown.d/20-wan-balancer")
        delete_list.append("/etc/config/wan_policy.json")

    def write_wan_manager_file(self, settings, prefix=""):
        """write_wan_manager_file writes /etc/config/wan_manager"""
        filename = prefix + self.wan_manager_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.wan_manager_file = open(filename, "w+")
        file = self.wan_manager_file

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")
        file.write("# Make sure default route is up to date\n")
        file.write("/etc/config/ifdown.d/10-default-route")
        file.write("\n\n")

        # Enable/Disable router advertisements for IPv6
        interfaces = settings.get('network').get('interfaces')
        for intf in interfaces:
            if intf.get('enabled'):
                if intf.get('routerAdvertisements'):
                    file.write("echo 1 > /proc/sys/net/ipv6/conf/%s/accept_ra || true\n" % intf.get('device'))
                else:
                    file.write("echo 0 > /proc/sys/net/ipv6/conf/%s/accept_ra || true\n" % intf.get('device'))

        wan = settings['wan']
        active_policy_ids = []
        policy_chains = wan.get('policy_chains')
        for policy_chain in policy_chains:
            for rule in policy_chain.get("rules"):
                if rule.get("enabled"):
                    action = rule.get("action")
                    if action.get("type") == "WAN_POLICY":
                        policy = action.get("policy")
                        if policy not in active_policy_ids:
                            active_policy_ids.append(policy)

        policies = wan.get('policies')
        for policy in policies:
            if policy.get('enabled'):
                policyId = policy.get('policyId')
                if policyId not in active_policy_ids:
                    continue
                interfaces = policy.get('interfaces')

                if len(interfaces) == 1 and interfaces[0].get('interfaceId') == 0:
                    interfaces = get_wan_list(settings)

                for intf in interfaces:
                    interfaceId = intf.get('interfaceId')
                    interfaceName = network_util.get_interface_name(settings, network_util.get_interface_by_id(settings, interfaceId), "ipv4")
                    interface6Name = network_util.get_interface_name(settings, network_util.get_interface_by_id(settings, interfaceId), "ipv6")
                    criteria = policy.get('criteria')
                    if criteria is None:
                        file.write("up policy-%d %d %s &\n" % (policyId, interfaceId, interfaceName))
                        if intf.get('ipv6Enabled'):
                            file.write("up policy-%d %d %s &\n" % (policyId, interfaceId, interface6Name))

                    else:
                        down_by_attribute = False
                        for criterion in criteria:
                            if criterion.get('type') == 'ATTRIBUTE':
                                if criterion.get('attribute') == 'VPN':
                                    if intf.get('type') != 'OPENVPN' and intf.get('type') != 'WIREGUARD':
                                        file.write("attribute policy-%d %d %s VPN down &\n" % (policyId, interfaceId, interfaceName))
                                        if intf.get('ipv6Enabled'):
                                            file.write("attribute policy-%d %d %s VPN down &\n" % (policyId, interfaceId, interface6Name))
                                        down_by_attribute = True
                                    else:
                                        file.write("attribute policy-%d %d %s VPN up &\n" % (policyId, interfaceId, interfaceName))
                                        if intf.get('ipv6Enabled'):
                                            file.write("attribute policy-%d %d %s &\n" % (policyId, interfaceId, interface6Name))
                                elif criterion.get('attribute') == 'NAME':
                                    name_contains = criterion.get('name_contains')
                                    if name_contains not in interfaceName:
                                        file.write("attribute policy-%d %d %s NAME %s down &\n" % (policyId, interfaceId, interfaceName, name_contains))
                                        down_by_attribute = True
                                    else:
                                        file.write("attribute policy-%d %d %s NAME %s up &\n" % (policyId, interfaceId, interfaceName, name_contains))
                                    #Also check for IPv6 interface names
                                    if intf.get('ipv6Enabled'):
                                        if name_contains not in interface6Name:
                                            file.write("attribute policy-%d %d %s NAME %s down &\n" % (policyId, interfaceId, interface6Name, name_contains))
                                            down_by_attribute = True
                                        else:
                                            file.write("attribute policy-%d %d %s NAME %s up &\n" % (policyId, interfaceId, interface6Name, name_contains))

                        if down_by_attribute is False:
                            file.write("up policy-%d %d %s &\n" % (policyId, interfaceId, interfaceName))
                            if intf.get('ipv6Enabled') and interfaceName != interface6Name:
                                file.write("up policy-%d %d %s &\n" % (policyId, interfaceId, interface6Name))

                            for criterion in criteria:
                                if criterion.get('type') == 'METRIC':
                                    metric_value = criterion.get('metric_value')

                                    metric = criterion.get('metric')
                                    if metric == 'LATENCY':
                                        stat_name = "latency"
                                        metric_name = "1_minute"
                                    elif metric == 'AVAILABLE_BANDWIDTH':
                                        stat_name = "available_bandwidth"
                                        metric_name = "1_minute"
                                    elif metric == 'JITTER':
                                        stat_name = "jitter"
                                        metric_name = "1_minute"
                                    elif metric == 'PACKET_LOSS':
                                        stat_name = "packet_loss"
                                        metric_name = "1_minute"

                                    metric_op = criterion.get('metric_op')
                                    if metric_op == "<":
                                        op="lt"
                                    elif metric_op == "<=":
                                        op="le"
                                    elif metric_op == ">":
                                        op="gt"
                                    elif metric_op == ">=":
                                        op="ge"

                                    file.write("metric policy-%d %d %s %s %s %s %d &\n" % (policyId, interfaceId, interfaceName, stat_name, metric_name, op, metric_value))
                                    if intf.get('ipv6Enabled'):
                                        file.write("metric policy-%d %d %s %s %s %s %d &\n" % (policyId, interfaceId, interface6Name, stat_name, metric_name, op, metric_value))


                                elif criterion.get('type') == 'CONNECTIVITY':
                                    test_type = criterion.get('connectivityTestType')
                                    interval = criterion.get('connectivityTestInterval')
                                    timeout = criterion.get('connectivityTestTimeout')
                                    threshold = criterion.get('connectivityTestFailureThreshold')
                                    target = criterion.get('connectivityTestTarget')
                                    if test_type == "PING":
                                        test="ping"
                                    elif test_type == "HTTP":
                                        test="http"
                                    elif test_type == "ARP":
                                        test="arp"
                                    elif test_type == "DNS":
                                        test="dns"
                                    file.write("test policy-%d %d %s %s %d %d %d %s &\n" % (policyId, interfaceId, interfaceName, test, interval, timeout, threshold, target))
                                    if intf.get('ipv6Enabled'):
                                        file.write("test policy-%d %d %s %s %d %d %d %s &\n" % (policyId, interfaceId, interface6Name, test, interval, timeout, threshold, target))

                if policy.get('type') == "SPECIFIC_WAN":
                    file.write("specific_wan policy-%d %d &\n" % (policyId, interfaceId))
                elif policy.get('type') == "BEST_OF":
                    best_of_metric = policy.get('best_of_metric')
                    if best_of_metric == "LOWEST_LATENCY":
                        stat_name = "latency"
                        metric_name = "1_minute"
                        op="le"
                    elif best_of_metric == "LOWEST_JITTER":
                        stat_name = "jitter"
                        metric_name = "1_minute"
                        op="le"
                    elif best_of_metric == "HIGHEST_AVAILABLE_BANDWIDTH":
                        stat_name = "available_bandwidth"
                        metric_name = "1_minute"
                        op="ge"
                    elif best_of_metric == "LOWEST_PACKET_LOSS":
                        stat_name = "packet_loss"
                        metric_name = "1_minute"
                        op="le"
                    file.write("best_of policy-%d %s %s %s &\n" % (policyId, stat_name, metric_name, op))
                elif policy.get('type') == "BALANCE":
                    algorithm = policy.get('balance_algorithm')
                    file.write("balance policy-%d %s &\n" % (policyId, algorithm))

        file.flush()
        file.close()

        print("%s: Wrote %s" % (self.__class__.__name__, filename))

    def write_wan_routing_file(self, settings, prefix=""):
        """write_wan_routing_file writes /etc/config/nftables-rules.d/102-wan-routing"""
        filename = prefix + self.wan_routing_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.wan_routing_file = open(filename, "w+")
        file = self.wan_routing_file

        file.write("#!/usr/bin/nft_debug -f")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")
        interfaces = settings.get('network').get('interfaces')

        self.write_wan_routing_tables(settings, file, interfaces, "ip")

        #Only write the ip6 wan-routing tables if any interfaces have ipv6 enabled

        self.write_wan_routing_tables(settings, file, interfaces, "ip6")

        file.flush()
        file.close()

        print("%s: Wrote %s" % (self.__class__.__name__, filename))
        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)


    def write_wan_routing_tables(self, settings, file, interfaces, family):
        """write_wan_routing_tables writes the specific ip family type rules and tables"""
        #This is used for rules that reference the ipvX_addr type
        ip_addr_family = "ipv4_addr"
        if family == "ip6":
            ip_addr_family = "ipv6_addr"

        file.write("\n")
        file.write("## %s family rules. ##\n" % family)
        file.write("\n")

        file.write("add table %s wan-routing\n" % family)
        file.write("flush table %s wan-routing\n" % family)
        file.write("add table %s wan-routing\n" % family)
        file.write("\n")

        file.write("add chain %s wan-routing restore-interface-marks\n" % family)
        file.write("add chain %s wan-routing restore-interface-marks-original\n" % family)
        file.write("add chain %s wan-routing restore-interface-marks-reply\n" % family)
        file.write("add rule %s wan-routing restore-interface-marks ct direction original jump restore-interface-marks-original\n" % family)
        file.write("add rule %s wan-routing restore-interface-marks ct direction reply jump restore-interface-marks-reply\n" % family)
        file.write("add rule %s wan-routing restore-interface-marks-original mark set ct mark and 0x%x\n" % (family, self.ALL_MASK))

        for intf in interfaces:
            if enabled_wan(intf):
                file.write("add set %s wan-routing wan-%d-table { type %s . %s; flags timeout; }\n" % (family, intf.get('interfaceId'), ip_addr_family, ip_addr_family))
                file.write("flush set %s wan-routing wan-%d-table\n" % (family, intf.get('interfaceId')))
                file.write("add chain %s wan-routing mark-for-wan-%d\n" % (family, intf.get('interfaceId')))
                file.write("add rule %s wan-routing mark-for-wan-%d mark set mark and 0xffff00ff or 0x%x\n" % (family, intf.get('interfaceId'), ((intf.get('interfaceId') << 8) & 0xff00)))
                file.write("add rule %s wan-routing mark-for-wan-%d set update %s saddr . %s daddr timeout 1m @wan-%d-table\n" % (family, intf.get('interfaceId'), family, family, intf.get('interfaceId')))
                file.write("add rule %s wan-routing mark-for-wan-%d set update %s daddr . %s saddr timeout 1m @wan-%d-table\n" % (family, intf.get('interfaceId'), family, family, intf.get('interfaceId')))
                file.write("add rule %s wan-routing mark-for-wan-%d accept\n" % (family, intf.get('interfaceId')))
                file.write("\n")

            if not intf.get('enabled'):
                continue
            if intf.get('configType') == 'BRIDGED':
                continue

            # just use the normal interface name
            # unless its a bridge and then use the bridge zone interface name
            interface_name = intf.get('netfilterDev')
            interface_type = 2 # lan
            if intf.get('wan'):
                interface_type = 1 # wan
            interface_id = intf.get('interfaceId')

            file.write("# if ct mark server interface is X then set the mark client interface to X\n")
            file.write("add rule %s wan-routing restore-interface-marks-reply ct mark and 0x%x == 0x%x mark set mark and 0x%x or 0x%x\n" %
                       (family, self.SERVER_INTERFACE_MASK, (interface_id << self.SERVER_INTERFACE_SHIFT), self.CLIENT_INTERFACE_MASK_INVERSE, interface_id << self.CLIENT_INTERFACE_SHIFT))
            file.write("# if ct mark server interface is X then set the mark client type to Xs type\n")
            file.write("add rule %s wan-routing restore-interface-marks-reply ct mark and 0x%x == 0x%x mark set mark and 0x%x or 0x%x\n" %
                       (family, self.SERVER_INTERFACE_MASK, (interface_id << self.SERVER_INTERFACE_SHIFT), self.CLIENT_TYPE_MASK_INVERSE, interface_type << self.CLIENT_TYPE_SHIFT))
            file.write("# if ct mark client interface is X then set the mark server interface to X\n")
            file.write("add rule %s wan-routing restore-interface-marks-reply ct mark and 0x%x == 0x%x mark set mark and 0x%x or 0x%x\n" %
                       (family, self.CLIENT_INTERFACE_MASK, (interface_id << self.CLIENT_INTERFACE_SHIFT), self.SERVER_INTERFACE_MASK_INVERSE, interface_id << self.SERVER_INTERFACE_SHIFT))
            file.write("# if ct mark client interface is X then set the mark server type to Xs type\n")
            file.write("add rule %s wan-routing restore-interface-marks-reply ct mark and 0x%x == 0x%x mark set mark and 0x%x or 0x%x\n" %
                       (family, self.CLIENT_INTERFACE_MASK, (interface_id << self.CLIENT_INTERFACE_SHIFT), self.SERVER_TYPE_MASK_INVERSE, interface_type << self.SERVER_TYPE_SHIFT))

        file.write("# restore reply direction interface marks for local output traffic\n")
        file.write("add rule %s wan-routing restore-interface-marks-reply ct mark and 0x%x == 0x%x mark set mark and 0x%x or 0x%x\n" %
                   (family, self.SERVER_INTERFACE_MASK, (255 << self.SERVER_INTERFACE_SHIFT), self.CLIENT_INTERFACE_MASK_INVERSE, 255 << self.CLIENT_INTERFACE_SHIFT))
        file.write("add rule %s wan-routing restore-interface-marks-reply ct mark and 0x%x == 0x%x mark set mark and 0x%x or 0x%x\n" %
                   (family, self.CLIENT_INTERFACE_MASK, (255 << self.CLIENT_INTERFACE_SHIFT), self.SERVER_INTERFACE_MASK_INVERSE, 255 << self.SERVER_INTERFACE_SHIFT))

        default_wan = 0
        for intf in interfaces:
            if enabled_wan(intf):
                default_wan = intf.get('interfaceId')
                break

        file.write("add chain %s wan-routing route-to-default-wan\n" % family)
        file.write("add rule %s wan-routing route-to-default-wan dict sessions ct id wan_policy long_string set system-default\n" % family)
        file.write("add rule %s wan-routing route-to-default-wan jump mark-for-wan-%d\n" % (family, default_wan))
        file.write("\n")
        file.write("add chain %s wan-routing update-rule-table\n" % family)
        file.write("\n")
        file.write("add chain %s wan-routing route-via-cache\n" % family)
        file.write("\n")

        wan = settings['wan']
        policies = wan.get('policies')
        for policy in policies:
            policyId = policy.get('policyId')

            file.write("add set %s wan-routing policy-%d-table { type %s . %s; flags timeout; }\n" % (family, policyId, ip_addr_family, ip_addr_family))
            file.write("flush set %s wan-routing policy-%d-table\n" % (family, policyId))
            file.write("add chain %s wan-routing route-to-policy-%d\n" % (family, policyId))
            file.write("add rule %s wan-routing route-to-policy-%d return comment \"policy disabled\"\n" % (family, policyId))
            file.write("add rule %s wan-routing route-via-cache %s saddr . %s daddr @policy-%d-table dict sessions ct id wan_policy long_string set policy-%d-cache log prefix \"{\'type\':\'rule\',\'table\':\'wan-routing\',\'chain\':\'route-via-cache\',\'ruleId\':-1,\'action\':\'WAN_POLICY\',\'policy\':%d}\" group 0\n" % (family, family, family, policyId, policyId, policyId))
            file.write("\n")

        enabled_policy_rules = []
        policy_chains = wan.get('policy_chains')
        for chain in policy_chains:
            chain_name = chain.get('name')
            chain_rules = chain.get('rules')
            for rule in chain_rules:
                if not rule.get('enabled'):
                    continue
                else:
                    ruleId = rule.get('ruleId')
                    file.write("add set %s wan-routing rule-%d-table { type %s . %s; flags timeout; }\n" % (family,  ruleId, ip_addr_family, ip_addr_family))
                    file.write("flush set %s wan-routing rule-%d-table\n" % (family, ruleId))
                    file.write("add chain %s wan-routing update-rule-%d-table\n" % (family, ruleId))
                    file.write("add rule %s wan-routing update-rule-%d-table set update %s saddr . %s daddr timeout 1m @rule-%d-table\n" % (family, ruleId, family, family, ruleId))
                    file.write("add rule %s wan-routing update-rule-%d-table set update %s daddr . %s saddr timeout 1m @rule-%d-table\n" % (family, ruleId, family, family, ruleId))
                    file.write("add rule %s wan-routing route-via-cache %s saddr . %s daddr @rule-%d-table log prefix \"{\'type\':\'rule\',\'table\':\'wan-routing\',\'chain\':\'%s\',\'ruleId\':%d,\'action\':\'WAN_POLICY\'}\" group 0\n" % (family, family, family, ruleId, chain_name, ruleId))
                    enabled_policy_rules.append("%d : jump update-rule-%d-table" % (ruleId, ruleId))

            file.write(nftables_util.chain_create_cmd(chain, family, None, "wan-routing") + "\n")
            file.write(nftables_util.chain_rules_cmds(chain, family, None, "wan-routing") + "\n")
            file.write("\n")

        file.write("add rule %s wan-routing update-rule-table dict sessions ct id wan_rule_id int vmap { %s }\n" % (family, ",".join(enabled_policy_rules)))

        for intf in interfaces:
            if enabled_wan(intf):
                file.write("add rule %s wan-routing route-via-cache %s saddr . %s daddr @wan-%d-table jump mark-for-wan-%d\n" % (family, family, family, intf.get('interfaceId'), intf.get('interfaceId')))

        file.write("add chain %s wan-routing wan-routing-entry\n" % family)
        file.write("add rule %s wan-routing wan-routing-entry jump route-via-cache\n" % family)
        file.write("add rule %s wan-routing wan-routing-entry jump user-wan-rules\n" % family)
        file.write("add rule %s wan-routing wan-routing-entry counter\n" % family)
        file.write("add rule %s wan-routing wan-routing-entry log prefix \"{\'type\':\'rule\',\'table\':\'wan-routing\',\'chain\':\'wan-routing-entry\',\'ruleId\':-2,\'action\':\'WAN_POLICY\',\'policy\':-2}\" group 0 jump route-to-default-wan\n" % family)
        file.write("add rule %s wan-routing wan-routing-entry counter\n" % family)

        file.write("\n")
        file.write("add chain %s wan-routing wan-routing-prerouting { type filter hook prerouting priority -25 ; }\n" % family)
        # MFW-948: Check if the packet SRC_TYPE mark is a WAN type, then just return from wan-routing-prerouting
        file.write("add rule %s wan-routing wan-routing-prerouting mark and 0x03000000 == 0x01000000 return\n" % family)
        file.write("add rule %s wan-routing wan-routing-prerouting mark and 0x0000ff00 != 0 return\n" % family)
        file.write("add rule %s wan-routing wan-routing-prerouting fib daddr type local return\n" % family)
        file.write("add rule %s wan-routing wan-routing-prerouting ct state new jump wan-routing-entry\n" % family)
        file.write("add rule %s wan-routing wan-routing-prerouting ct state invalid counter\n" % family)
        file.write("add rule %s wan-routing wan-routing-prerouting ct state established counter\n" % family)
        file.write("add rule %s wan-routing wan-routing-prerouting ct state related counter\n" % family)

        file.write("\n")
        file.write("add chain %s wan-routing wan-routing-output { type route hook output priority -150 ; }\n" % family)
        file.write("add rule %s wan-routing wan-routing-output jump restore-interface-marks\n" % family)
        file.write("add rule %s wan-routing wan-routing-output ct state new ct mark set ct mark and 0x%x or 0x%x\n" %
                   (family, self.CLIENT_INTERFACE_MASK_INVERSE, (self.LOCAL_INTERFACE_ID << self.CLIENT_INTERFACE_SHIFT)))
        file.write("add rule %s wan-routing wan-routing-output ct state new ct mark set ct mark and 0x%x or 0x%x\n" %
                   (family, self.CLIENT_TYPE_MASK_INVERSE, (2 << self.CLIENT_TYPE_SHIFT) & self.CLIENT_TYPE_MASK))
        file.write("add rule %s wan-routing wan-routing-output mark set mark and 0x%x or 0x%x\n" %
                   (family, self.SRC_INTERFACE_MASK_INVERSE, (self.LOCAL_INTERFACE_ID << self.SRC_INTERFACE_SHIFT)))
        file.write("add rule %s wan-routing wan-routing-output mark set mark and 0x%x or 0x%x\n" %
                   (family, self.SRC_TYPE_MASK_INVERSE, (2 << self.SRC_TYPE_SHIFT) & self.SRC_TYPE_MASK))
        for intf in interfaces:
            if not intf.get('enabled'):
                continue
            if intf.get('configType') == 'BRIDGED':
                continue
            if intf.get('wan'):
                continue
            file.write("add rule %s wan-routing wan-routing-output oifname %s return\n" % (family, intf.get('netfilterDev')))
        file.write("add rule %s wan-routing wan-routing-output mark and 0x0000ff00 != 0 return\n" % family)
        file.write("add rule %s wan-routing wan-routing-output oif lo return\n" % family)
        file.write("add rule %s wan-routing wan-routing-output ct state new jump wan-routing-entry\n" % family)
        file.write("add rule %s wan-routing wan-routing-output ct state invalid counter\n" % family)
        file.write("add rule %s wan-routing wan-routing-output ct state established counter\n" % family)
        file.write("add rule %s wan-routing wan-routing-output ct state related counter\n" % family)

    def write_rt_tables_file(self, settings, prefix=""):
        """write_rt_tables_file writes /etc/iproute2/rt_tables"""
        filename = prefix + self.rt_tables_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.rt_tables_file = open(filename, "w+")
        file = self.rt_tables_file

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        file.write("#\n")
        file.write("# reserved values\n")
        file.write("#\n")
        file.write("128\tprelocal\n")
        file.write("255\tlocal\n")
        file.write("254\tmain\n")
        file.write("253\tdefault\n")
        file.write("0\tunspec\n")
        file.write("#\n")
        file.write("# local\n")
        file.write("#\n")
        file.write("#1\tinr.ruhep\n")
        file.write("\n\n")
        file.write("#\n")
        file.write("# WAN tables\n")
        file.write("#\n")

        interfaces = settings.get('network').get('interfaces')
        for intf in interfaces:
            if enabled_wan(intf):
                interface_id = intf.get('interfaceId')
                file.write("%d\twan.%d\n" % (interface_id, interface_id))

        file.write("\n\n")

        file.flush()
        file.close()

        print("%s: Wrote %s" % (self.__class__.__name__, filename))

    def write_ifup_routes_file(self, settings, prefix=""):
        """write_ifup_routes_file writes /etc/config/ifup.d/10-default-route"""
        filename = prefix + self.ifup_routes_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.ifup_route_file = open(filename, "w+")
        file = self.ifup_route_file
        file.write("#!/bin/sh")
        file.write("\n\n")
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n")
        file.write(". /lib/functions/network.sh\n")
        file.write("\n")
        file.write("INTERFACE=$1\n")
        file.write("DEVICE=$2\n")
        file.write("\n")

        if get_number_of_wans(settings) == 1:
            file.write("\n# Only one wan, do nothing\n\n")
        else:
            file.write("write_rules()\n")
            file.write("{\n")
            file.write("\tnft -f $TMPFILE\n")
            file.write("\tretval=$?\n")
            file.write("\twhile [ $retval -ne 0 ] ; do\n")
            file.write("\t\tnft -f $TMPFILE\n")
            file.write("\t\tretval=$?\n")
            file.write("\tdone\n")
            file.write("\trm $TMPFILE\n")
            file.write("\texit 0\n")
            file.write("}\n\n")

            interfaces = settings.get('network').get('interfaces')
            for intf in interfaces:
                if enabled_wan(intf):
                    if intf.get('v4ConfigType') != 'DISABLED':
                        self.create_ifup_default_route(file, intf.get('interfaceId'),network_util.get_interface_name(settings, intf, 'ipv4'), "ip")

                    if intf.get('v6ConfigType') != 'DISABLED':
                        self.create_ifup_default_route(file, intf.get('interfaceId'),network_util.get_interface_name(settings, intf, 'ipv6'), "ip6")

        file.flush()
        file.close()
        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)

        print("%s: Wrote %s" % (self.__class__.__name__, filename))

    def create_ifup_default_route(self, file, interfaceId, interfaceName, tablefamily):
        """create_ifup_default_route creates a validation for checking if the route-to-default-wan chains are updated"""
        file.write("[ %s = \"$INTERFACE\" ] && {\n" % interfaceName)
        file.write("\tnft list chain %s wan-routing route-to-default-wan | grep -q mark-for-wan- || {\n" % tablefamily)
        file.write("\t\tTMPFILE=`mktemp -t default-route.XXXXXX`\n")
        file.write("\t\techo flush chain %s wan-routing route-to-default-wan >> $TMPFILE\n" % tablefamily)
        file.write("\t\techo add rule %s wan-routing route-to-default-wan dict sessions ct id wan_policy long_string set system-default >> $TMPFILE\n" % tablefamily)
        file.write("\t\techo add rule %s wan-routing route-to-default-wan jump mark-for-wan-%d >> $TMPFILE\n" % (tablefamily, interfaceId))
        file.write("\t\twrite_rules\n")
        file.write("\t}\n")
       # file.write("\texit 0\n")
        file.write("}\n\n")


    def write_ifdown_routes_file(self, settings, prefix=""):
        """write_ifdown_routes_file writes /etc/config/ifdown.d/10-default-route"""
        filename = prefix + self.ifdown_routes_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.ifdown_route_file = open(filename, "w+")
        file = self.ifdown_route_file
        file.write("#!/bin/sh")
        file.write("\n\n")
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n")
        file.write(". /lib/functions/network.sh\n")
        file.write("\n")
        file.write("INTERFACE=$1\n")

        if get_number_of_wans(settings) == 1:
            file.write("\n# Only one wan, do nothing\n\n")
        else:
            file.write("write_rules()\n")
            file.write("{\n")
            file.write("\tnft -f $TMPFILE\n")
            file.write("\tretval=$?\n")
            file.write("\twhile [ $retval -ne 0 ] ; do\n")
            file.write("\t\tnft -f $TMPFILE\n")
            file.write("\t\tretval=$?\n")
            file.write("\tdone\n")
            file.write("\trm $TMPFILE\n")
            file.write("\texit 0\n")
            file.write("}\n\n")
            file.write("update_default_route()\n")
            file.write("{\n")
            file.write("\n")

            interfaces = settings.get('network').get('interfaces')
            for intf in interfaces:
                if enabled_wan(intf):
                    if intf.get('v4ConfigType') != 'DISABLED':
                        self.create_ifdown_default_route(file, intf.get('interfaceId'), network_util.get_interface_name(settings, intf, 'ipv4'), "ip")

                    if intf.get('v6ConfigType') != 'DISABLED':
                        self.create_ifdown_default_route(file, intf.get('interfaceId'), network_util.get_interface_name(settings, intf, 'ipv6'), "ip6")

            file.write("}\n\n")

            for intf in interfaces:
                if enabled_wan(intf):
                    if intf.get('v4ConfigType') != 'DISABLED':
                        self.create_ifdown_call_update_route(file, intf.get('interfaceId'), network_util.get_interface_name(settings, intf, 'ipv4'), "ip")
                    
                    if intf.get('v6ConfigType') != 'DISABLED':
                        self.create_ifdown_call_update_route(file, intf.get('interfaceId'), network_util.get_interface_name(settings, intf, 'ipv6'), "ip6")

            file.write("[ -z \"$INTERFACE\" ] && {\n")
            file.write("\tupdate_default_route\n")
            file.write("}\n\n")

        file.flush()
        file.close()
        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)

        print("%s: Wrote %s" % (self.__class__.__name__, filename))

    def create_ifdown_default_route(self, file, interfaceId, interfaceName, tablefamily):
        """create_ifdown_default_route will create the default route rules for specific ip table families into a file"""
        file.write("\tnetwork_is_up %s && {\n" % interfaceName)
        file.write("\t\tTMPFILE=`mktemp -t default-route.XXXXXX`\n")
        file.write("\t\techo flush chain ip wan-routing route-to-default-wan >> $TMPFILE\n")
        file.write("\t\techo flush chain ip6 wan-routing route-to-default-wan >> $TMPFILE\n")
        file.write("\t\techo add rule %s wan-routing route-to-default-wan dict sessions ct id wan_policy long_string set system-default >> $TMPFILE\n" % tablefamily)
        file.write("\t\techo add rule %s wan-routing route-to-default-wan jump mark-for-wan-%d >> $TMPFILE\n" % (tablefamily, interfaceId))
        file.write("\t\twrite_rules\n")
        file.write("\t}\n\n")

    def create_ifdown_call_update_route(self, file, interfaceId, interfaceName, tablefamily):
        """create_ifdown_call_update_route will write the rules that check the interface that called ifdown, and then call update_def_route if rules exist"""
        file.write("[ %s = \"$INTERFACE\" ] && {\n" % interfaceName)
        file.write("\tnft list chain %s wan-routing route-to-default-wan | grep -q mark-for-wan-%d && {\n" % (tablefamily, interfaceId))
        file.write("\t\tupdate_default_route\n")
        file.write("\t}\n")
        file.write("}\n\n")

def get_number_of_wans(settings):
    """returns number of enabled wan interfaces"""
    wans = 0
    interfaces = settings.get('network').get('interfaces')
    for intf in interfaces:
        if enabled_wan(intf):
            wans += 1

    return wans

def enabled_wan(intf):
    """returns true if the interface is an enabled wan"""
    if intf is None:
        return False

    if intf.get('enabled') and intf.get('wan'):
        return True
    return False

def get_wan_list(settings):
    """
    returns a list of wan_interface's for all enabled wans
    """
    wan_list = []
    interfaces = settings.get('network').get('interfaces')
    for intf in interfaces:
        if enabled_wan(intf):
            wan = {
                "interfaceId": intf.get('interfaceId'),
                "weight": 1,
                "ipv6Enabled": 'v6ConfigType' in intf and intf.get('v6ConfigType') != 'DISABLED'
            }
            wan_list.append(wan)

    return wan_list


registrar.register_manager(RouteManager())
