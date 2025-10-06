<template>
  <rules-list
    :title="title"
    :description="description"
    :rules="rules"
    :type="ruleType"
    @refresh="onRefresh"
    @rules-change="validateRulesAndSetWarning"
  >
    <template #actions="{ updatedRules, isDirty }">
      <u-btn :min-width="null" :disabled="!isDirty" @click="onSave(updatedRules)">
        {{ $t('save') }}
      </u-btn>
    </template>
    <template #extra-fields>
      <u-alert v-if="warning" :error="true" class="mb-1">
        <span>{{ $t(warning) }}<br /></span>
      </u-alert>
    </template>
    <template #rules-footer>
      <div v-if="footer">
        <v-divider class="my-2" />
        <u-alert class="mb-1">
          <span v-html="footer"></span>
        </u-alert>
      </div>
    </template>
  </rules-list>
</template>
<script>
  import { get } from 'lodash'
  import cloneDeep from 'lodash/cloneDeep'
  import { RulesList } from 'vuntangle'
  import settingsMixin from '../settingsMixin'
  import store from '@/store'
  import util from '@/util/util'

  export default {
    components: { RulesList },
    mixins: [settingsMixin],

    /**
     * Using provide/inject to pass extra data to rules list vuntangle component to avoid props drilling
     * Vuntangle component stack:
     * Rules List > Rules Grid
     *            > Rule Dialog > RuleCondition
     *                          > Rule Action
     * Any descending component can use
     * `inject: ['$remoteData', '$features', ...]`
     * to have access to data
     * Those were prefixed with `$` to make a distinction between other local props/data from components
     *
     * $remoteData - provides data which is outside of the rules
     * $remoteData.interfaces
     *    - must be an array of interfaces usable for select fields: { text: 'interface_name', value: 'interface_id' }
     *
     * $readOnly - wheather appliance is offline in ETM and rules cannot be edited but just listed
     */
    provide() {
      return {
        $remoteData: () => ({
          interfaces: this.interfaces,
        }),
        $features: {
          hasIpv6Support: true,
        },
        $readOnly: false,
      }
    },
    data() {
      return {
        // Network rules config names
        networkRules: ['port-forward-rules', 'nat-rules', 'bypass-rules', 'filter-rules', 'access-rules'],
        /**
         * a map between rule type (port-forward rules, nat rules), coming from route prop
         * and the rule configuration names mapped to the appliance settings
         * found in /vuntangle/src/shared/Conditions/data/rulesDefinitions.js
         */
        rulesMap: {
          'port-forward': ['port-forward-rules'],
          'nat': ['nat-rules'],
          'bypass': ['bypass-rules'],
          'filter': ['filter-rules'],
          'access': ['access-rules'],
        },
        // warning message to be shown in the extra-fields slot
        warning: null,
        footer: null,
      }
    },

    computed: {
      // Rule type coming from route
      ruleType: ({ $route }) => $route.params.ruleType,

      // translated main title of the view based on the rule type
      title: ({ ruleType, $i18n }) => $i18n.t(ruleType.replace(/-/g, '_')),

      description: ({ ruleType, $i18n }) => {
        if (ruleType === 'port-forward') return $i18n.t('port_forward_description')
        if (ruleType === 'nat') return $i18n.t('nat_description')
        if (ruleType === 'bypass') return $i18n.t('bypass_description')
        if (ruleType === 'filter') return $i18n.t('filter_description')
        if (ruleType === 'access') return $i18n.t('read_only_rules_description')
      },

      // the network settings from the store
      networkSettings: ({ $store }) => $store.getters['settings/networkSetting'],

      // the system settings from the store
      systemSettings: ({ $store }) => $store.getters['settings/systemSetting'],

      // rule configuration names associated with a given rule type
      ruleConfigs: ({ rulesMap, ruleType }) => rulesMap[ruleType],

      /**
       * Returns the actual rules extracted from settings based on each configuration
       * @param {Object} vm - vue instance
       * @param {Object} vm.networkSettings - appliance settings
       * @param {Array<string>} vm.ruleConfigs - names of the configurations
       * @returns {Object} - with mapping between config name and the rules
       */
      rules: ({ networkSettings, ruleConfigs, networkRules }) => {
        const rules = {}

        ruleConfigs.forEach(confName => {
          // For Network Settings Rules
          if (networkRules.includes(confName)) {
            rules[confName] = get(networkSettings, confName.replace(/-/g, '_')) || []
          }
        })
        return rules
      },

      /**
       * Returns the interfaces list based on the network settings and rule type
       * @param {Object} vm - vue instance
       * @param {Object} vm.networkSettings - appliance settings
       * @param {String} vm.ruleType - type of the rule
       * @returns {Array} - list of interfaces usable for select fields
       */
      interfaces: ({ networkSettings, ruleType }) => {
        let interfaces = []
        if (['port-forward', 'nat', 'bypass', 'filter', 'access'].includes(ruleType)) {
          interfaces = util.getInterfaceList(networkSettings, true, true)
        }
        return interfaces
      },
    },

    watch: {
      rules: {
        deep: true,
        immediate: true,
        // Whenever rules change, check for warnings
        handler(newVal) {
          this.validateRulesAndSetWarning(newVal)
        },
      },
    },

    created() {
      this.fetchSettings(false)
      if (this.ruleType === 'port-forward') {
        this.setPortForwardWarnings()
      }
    },

    methods: {
      /**
       * Handler when using grid 'Refresh' action
       * Calls respective store dispatchers to re-fetch the rules based on their type
       */
      onRefresh() {
        this.fetchSettings(true)
      },

      /**
       * Fetches the settings and updates the store.
       * If refetch is true, it forces a re-fetch of the settings.
       * @param {boolean} refetch - Whether to force a re-fetch of the settings.
       */
      fetchSettings(refetch) {
        store.commit('SET_LOADER', true)
        Promise.all(
          this.ruleConfigs.map(async confName => {
            // For Network Settings Rules Refresh Network Settings
            if (this.networkRules.includes(confName)) {
              await store.dispatch('settings/getNetworkSettings', refetch)
            }
            if (confName === 'port-forward-rules') {
              await store.dispatch('settings/getSystemSettings', false)
            }
          }),
        ).finally(() => {
          store.commit('SET_LOADER', false)
        })
      },

      /**
       * saves or updates existing rules
       * by cloning the original settings and setting new rules on it,
       * than dispatching the store action to save the settings
       * @param {String} rules - the new / updated rules passed via #actions slot props
       */
      onSave(updatedRules) {
        store.commit('SET_LOADER', true)

        Promise.all(
          this.ruleConfigs.map(async confName => {
            // For Network Settings Rules Save Network Settings
            if (this.networkRules.includes(confName)) {
              if (confName === 'access-rules') {
                const confirmed = await this.showAccessRulesWarning()
                if (!confirmed) {
                  return
                }
              }
              const networkSettingsCopy = cloneDeep(this.networkSettings)
              Object.entries(updatedRules).forEach(([key, rules]) => {
                networkSettingsCopy[key.replace(/-/g, '_')] = rules
              })

              await store.dispatch('settings/setNetworkSettingV2', networkSettingsCopy)
            }
          }),
        ).finally(() => {
          store.commit('SET_LOADER', false)
        })
      },

      /**
       * Sets the footer warnings for port forwarding based on current network interfaces
       * and system settings. It checks each interface's status and generates appropriate
       * warnings about reserved ports for HTTP and HTTPS access.
       */
      async setPortForwardWarnings() {
        try {
          const status = await new Promise((resolve, reject) =>
            window.rpc.networkManager.getAllInterfacesStatusV2((res, err) => (err ? reject(err) : resolve(res))),
          )

          const networkSettingsCopy = cloneDeep(this.networkSettings || {})
          const interfaces = networkSettingsCopy.interfaces || []

          const statusMap = (Array.isArray(status) ? status : []).reduce((map, s) => {
            if (s && s.interfaceId) map[s.interfaceId] = s
            return map
          }, {})

          interfaces.forEach(iface => {
            const intfStatus = statusMap[iface.interfaceId]
            if (intfStatus) Object.assign(iface, intfStatus)
          })

          // Collect HTTPS IPs (all interfaces with an IPv4)
          const httpsIps = interfaces
            .filter(intf => intf && intf.v4Address)
            .map(intf => intf.v4Address)
            .join(', ')

          // Collect HTTP IPs:
          // - For non-WAN: include its IP
          // - For WAN: include ONLY bridged entries "(Bridge Interface: Name)" if any; otherwise include nothing
          const httpEntries = interfaces
            .filter(intf => intf && intf.v4Address)
            .flatMap(intf => {
              if (intf.wan) {
                const bridged = interfaces
                  .filter(sub => sub.configType === 'BRIDGED' && sub.bridgedTo === intf.interfaceId)
                  .map(subIntf =>
                    this.$t('port_forward_http_bridge', [intf.v4Address, (subIntf && subIntf.name) || '']),
                  )
                return bridged.length ? bridged : []
              }
              return [intf.v4Address]
            })

          const httpIps = httpEntries.join(', ')

          // Build footer text
          this.footer = `
            <p>${this.$t('port_forward_reserved_title')}</p>
            <p>${this.$t('port_forward_https_usage', [this.systemSettings?.httpsPort || '443', httpsIps])}<br />
              ${this.$t('port_forward_http_usage', [this.systemSettings?.httpPort || '80', httpIps])}</p>
          `
        } catch (err) {
          this.footer = '' // safe fallback
        }
      },

      /**
       * Validates the given set of rules based on the current rule type,
       * and updates the component's `warning` property if conflicts or
       * unsafe configurations are detected.
       *
       * @param {Object} rules - The rules object to validate, keyed by rule type
       *                         (e.g., { 'bypass-rules': [...] }).
       * @returns {void} - Updates `this.warning` in-place with a translated
       *                   warning message string or `null` if no conflicts.
       */
      validateRulesAndSetWarning(rules) {
        if (this.ruleType === 'bypass') {
          const lanIpAddrs = util.getLanIpAddrs(this.networkSettings)
          const hasConflict = this.isBypassRuleConflict(rules['bypass-rules'], lanIpAddrs)

          this.warning = hasConflict ? this.$t('bypass_rules_warning_lan_ip_addrs') : null
        } else {
          this.warning = null
        }
      },

      /**
       * Checks if any bypass rule's SRC_ADDR condition conflicts with LAN IP addresses.
       * A conflict occurs if a bypass rule would inadvertently include LAN IPs,
       * potentially exposing internal traffic to bypass filtering.
       *
       * @param {Array} bypassRules - Array of bypass rule objects to check.
       * @param {Array} lanIpAddrs - Array of LAN IP addresses as strings.
       * @returns {boolean} - True if a conflict is found, false otherwise.
       */
      isBypassRuleConflict(bypassRules, lanIpAddrs) {
        if (!bypassRules || bypassRules.length === 0 || !lanIpAddrs || lanIpAddrs.length === 0) {
          return false
        }

        return bypassRules?.some(rule =>
          rule.conditions?.some(condition => {
            if (condition?.type !== 'SRC_ADDR') return false

            // Split by commas (can contain IPs, ranges, or IP/mask format)
            const condValues = condition.value.split(',').map(v => v.trim())

            return condValues.some(expr =>
              lanIpAddrs.some(lanIp => {
                if (expr.includes('-')) {
                  return util.isIpInRange(lanIp, expr) // Range check
                } else {
                  // Strip /mask if present (e.g., 192.168.56.186/24 → 192.168.56.186)
                  const baseIp = expr.includes('/') ? expr.split('/')[0] : expr
                  return lanIp === baseIp
                }
              }),
            )
          }),
        )
      },

      /**
       * Displays a confirmation dialog when Access Rules are saved.
       *
       * Shows a modal with a title, message, and Yes/No buttons.
       * Resolves a Promise with `true` if the user clicks Yes,
       * or `false` if the user clicks No or cancels the dialog.
       * @returns {Promise<boolean>} Resolves to true/false based on user choice.
       */
      showAccessRulesWarning() {
        return new Promise(resolve => {
          this.$vuntangle.confirm.show({
            title: this.$t('access_rules_changed'),
            message: this.$t('access_rules_warning'),
            confirmLabel: this.$vuntangle.$t('yes'),
            cancelLabel: this.$vuntangle.$t('no'),
            action() {
              this.onClose()
              resolve(true)
            },
            cancel() {
              this.onClose()
              resolve(false)
            },
          })
        })
      },

      /**
       * Optional hook triggered on browser refresh. refetches the settings.
       */
      onBrowserRefresh() {
        this.fetchSettings(true)
      },
    },
  }
</script>
