<template>
  <rules-list :title="title" :description="description" :rules="rules" :type="ruleType" @refresh="onRefresh">
    <template #actions="{ updatedRules, isDirty }">
      <u-btn :min-width="null" :disabled="!isDirty" @click="onSave(updatedRules)">
        {{ $t('save') }}
      </u-btn>
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
        networkRules: ['port-forward-rules', 'nat-rules', 'bypass-rules', 'filter-rules'],
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
        },
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
      },

      // the network settings from the store
      networkSettings: ({ $store }) => $store.getters['settings/networkSetting'],

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
        if (['port-forward', 'nat', 'bypass', 'filter'].includes(ruleType)) {
          interfaces = util.getInterfaceList(networkSettings, true, true)
        }
        return interfaces
      },
    },

    created() {
      this.fetchSettings(false)
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
       * Optional hook triggered on browser refresh. refetches the settings.
       */
      onBrowserRefresh() {
        this.fetchSettings(true)
      },
    },
  }
</script>
