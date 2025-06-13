<template>
  <rules-list
    :title="title"
    :description="description"
    :rules="rules"
    :type="ruleType"
    :cloud-config-id="cloudConfigId"
    :has-cloud-policies="hasCloudPolicies"
    @fetch-classify-apps="onFetchClassifyApps"
    @fetch-networks-uri="onFetchNetworksUri"
    @refresh="onRefresh"
  >
    <template #actions="{ updatedRules, isDirty }">
      <u-btn :min-width="null" text class="mr-2" @click="onResetDefaults">{{ $t('reset_to_defaults') }}</u-btn>
      <u-btn :min-width="null" :disabled="!isDirty" @click="onSave(updatedRules)">
        {{ $t('save') }}
      </u-btn>
    </template>
  </rules-list>
</template>
<script>
  // import get from 'lodash/get'
  // import cloneDeep from 'lodash/cloneDeep'
  // import ruleDefs from 'vuntangle'
  import RulesList from '@/components/Reusable/Rules/RulesList.vue'
  import store from '@/store'
  import Util from '@/util/setupUtil'
  // import uris from '@/util/uris'

  export default {
    components: { RulesList },

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
     *    - used for INTERFACE_ZONE conditions and rendering inside grids
     * $remoteData.wanPolicies
     *    - must be an array of Wan Policies usable for select fields: { text: 'policy_description', value: 'policy_id' }
     *    - used for selecting WAN_POLICY action for wan rules, also rendering inside grids
     * $remoteData.serviceStatus
     *    - map between service name and it's enabled state, e.g. { application_control: true, geoip: false }
     *    - used to validate conditions which require certain services to be enabled, e.g. APPLICATION based conditions requires application control service to be enabled
     * $remoteData.etmNetworksUri
     *    - the external ETM URL used by command center rules which cannot be edited in local UI
     * $remoteData.classifyApplication
     *    - the classify application as provided by the box via API /api/classify/applications
     *    - used for APPLICATION_CATEGORY, APPLICATION_NAME conditions
     *
     * $features - provides specific features which can be based on different box versions; it's important for ETM
     * $features.hasManagementIntf - whether is an EOS appliance having management interface
     * $features.hasAboveLayer3Conditions - whether appliance supports conditions above layer 3
     * $features.hasRuleLogs - whether appliance supports Rule Logs introduced in 6.1 for access, filter & bypass rules
     * $features.hasLimitingRules - whether to use limiting_rules chain instead of having only prioritization rules for Shaping
     *
     * $readOnly - wheather appliance is offline in ETM and rules cannot be edited but just listed
     */
    provide() {
      return {
        $remoteData: () => ({
          interfaces: this.interfaces,
          wanPolicies: this.wanPolicies,
          serviceStatus: this.serviceStatus,
          etmNetworksUri: this.etmNetworksUri,
          classifyApplications: this.applications,
        }),
        $features: {
          hasManagementIntf: false,
          hasAboveLayer3Conditions: true,
          hasRuleLogs: true,
          hasLimitingRules: true,
          hasQosmos: this.$store.getters['hardware/platform'] === 'MFW_EOS',
        },
        $readOnly: false,
      }
    },
    data() {
      return {
        /**
         * a map between rule type (firewall table, wan rules or bypass rules), coming from route prop
         * and the rule configuration names mapped to the appliance settings
         * found in /vuntangle/src/shared/Conditions/data/rulesDefinitions.js
         */
        rulesMap: {
          'port-forward': ['port-forward-rules'],
          // 'shaping': ['prioritization-rules', 'limiting-rules'],
          // 'nat': ['nat-rules'],
          // 'wan-rules': ['command-center-rules', 'user-wan-rules'],
          // 'filter': ['filter-rules'],
          // 'access': ['access-rules'],
          // 'bypass': ['bypass-rules'],
        },

        // external etm networks link
        // etmNetworksUri: undefined,
      }
    },

    computed: {
      // one of the 7 rule types coming from route
      ruleType: ({ $route }) => $route.params.ruleType,

      // translated main title of the view based on the rule type
      title: ({ ruleType, $i18n }) => $i18n.t(ruleType.replace(/-/g, '_')),

      description: ({ ruleType, $i18n }) => {
        if (ruleType === 'port-forward-rules') return $i18n.t('port_forward_description')
        // if (ruleType === 'shaping') return $i18n.t('shaping_rules_description')
        // if (ruleType === 'bypass') return $i18n.t('bypass_description')
      },

      // whole settings of the appliance
      boxSettings: ({ $store }) => $store.getters['settings/settings'],

      // Network Settings
      networkSettings: () => {
        const rpc = Util.setRpcJsonrpc('admin')
        return rpc.networkManager.getNetworkSettings()
      },

      // rule configuration names associated with a given rule type
      ruleConfigs: ({ rulesMap, ruleType }) => rulesMap[ruleType],

      /**
       * Returns the actual rules extracted from settings based on each configuration
       * @param {Object} vm - vue instance
       * @param {Object} vm.boxSettings - appliance settings
       * @param {Array<string>} vm.ruleConfigs - names of the configurations
       * @returns {Object} - with mapping between config name and the rules
       */
      rules: ({ networkSettings }) => {
        // if (templateRules) {
        //   return { 'bypass-rules': templateRules }
        // }

        const rules = { 'port-forward-rules': networkSettings.portForwardRules }
        return rules
      },

      // the interfaces array as {text, value} used in select fields
      interfaces: ({ $store }) => $store.getters['settings/addressedInterfacesOptions'],

      // Wan Polcies array as {text, value} used in select fields
      wanPolicies: ({ $store }) =>
        $store.getters['settings/wanPolicies']?.map(policy => ({ text: policy.description, value: policy.policyId })),

      // Status of services used on validating APPLICATION or GEOIP based conditions
      // serviceStatus: ({ boxSettings }) => ({
      //   application_control: boxSettings?.application_control.enabled,
      //   geoip: boxSettings?.geoip.enabled,
      // }),

      // classify applications used for APPLICATION based conditions
      applications: ({ $store }) => $store.getters['classify/applications'],

      cloudConfigId: ({ $store, ruleType }) => $store.getters['settings/cloudManaged']?.[ruleType],
      hasCloudPolicies: ({ $store }) => $store.getters['settings/hasCloudPolicies'],
    },

    created() {
      // sets the help url context based on rule type
      let context = this.ruleType.replace(/-/g, '_')
      if (context !== 'wan_rules') context += '_rules'
      store.commit('SET_HELP_CONTEXT', context)
    },

    methods: {
      /**
       * Dispatches action to fetch the classify apps passed via provide $classifyApplications
       * Gets called from rule conditions when having APPLICATION based conditions
       */
      async onFetchClassifyApps() {
        await this.$store.dispatch('classify/getApplications')
      },

      async onFetchNetworksUri() {
        // this.etmNetworksUri = await uris.translate(uris.list.networks)
      },

      /**
       * confirm dialog to reset rules to their system defaults
       */
      onResetDefaults() {
        const message = this.ruleType === 'wan-rules' ? 'reset_wan_warning' : 'reset_rules_warning'
        const successMessage = this.ruleType === 'wan-rules' ? 'reset_wan_success' : 'reset_rules_success'
        this.$vuntangle.confirm.show({
          title: `<i class="mdi mdi-alert" style="font-style: normal;"> ${this.$t('warning')}</i>`,
          message: this.$t(message),
          confirmLabel: this.$t('yes'),
          cancelLabel: this.$t('no'),
          action: async resolve => {
            let response
            if (this.ruleType === 'bypass') {
              response = await store.dispatch('settings/resetBypassRulesToDefaults')
            } else if (this.ruleType !== 'wan-rules') {
              response = await store.dispatch('settings/resetRulesToDefaults', { ruleType: this.ruleType })
            } else {
              response = await store.dispatch('settings/resetWanToDefaults')
            }
            if (response) {
              this.$vuntangle.toast.add(this.$t(successMessage))
            }
            resolve()
          },
        })
      },

      /**
       * Handler when using grid 'Refresh' action
       * Calls respective store dispatchers to re-fetch the rules based on their type
       */
      onRefresh() {
        if (this.ruleType === 'wan-rules') {
          this.$store.dispatch('settings/getWan')
          return
        }
        if (this.ruleType === 'bypass') {
          this.$store.dispatch('settings/getBypass')
          return
        }
        // otherwise it's a firewall table
        this.$store.dispatch('settings/getTable', this.ruleType)
      },

      /**
       * saves or updates existing rules
       * by cloning the original chain and setting new rules on it,
       * than dispatching the store action to save the chain
       * @param {String} rules - the new / updated rules passed via #actions slot props
       */
      async onSave(updatedRules) {
        this.$store.commit('SET_LOADER', true)
        switch (this.ruleType) {
          case 'port-forward-rules': {
            const rpc = Util.setRpcJsonrpc('admin')
            this.networkSettings.portForwardRules = updatedRules['port-forward-rules']
            await rpc.networkManager.setNetworkSettings(this.networkSettings)
            break
          }
          // case 'bypass': {
          //   result = await store.dispatch('settings/setBypass', { bp: { rules: updatedRules['bypass-rules'] } })
          //   break
          // }
          // case 'wan-rules': {
          //   const wan = cloneDeep(this.boxSettings.wan)
          //   const localChain = wan.policy_chains.find(chain => chain.name === 'user-wan-rules')
          //   localChain.rules = updatedRules['user-wan-rules']
          //   result = await store.dispatch('settings/setWan', { wan })
          //   break
          // }
          default: {
            // const table = cloneDeep(get(this.boxSettings, `firewall.tables.${this.ruleType}`))
            // Object.entries(updatedRules).forEach(([key, rules]) => {
            //   const chain = table.chains.find(chain => chain.name === key)
            //   chain.rules = rules
            // })
            // result = await store.dispatch('settings/setTable', table)
          }
        }
        this.$store.commit('SET_LOADER', false)
        // if (result.success) {
        //   this.$vuntangle.toast.add(this.$t('saved_successfully', [this.$t('rules')]))
        // } else {
        //   this.$vuntangle.toast.add(this.$t('rolled_back_settings', [result.message]))
        // }
      },
    },
  }
</script>
