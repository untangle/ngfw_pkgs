<template>
  <rules-list
    :title="title"
    :description="description"
    :rules="rules"
    :type="ruleType"
    :hide-refresh-button="true"
    :hide-export-csv-button="true"
    :hide-export-settings-button="false"
    :hide-import-settings-button="false"
    style="height: 878px"
    @rules-change="onRulesChange"
  ></rules-list>
</template>
<script>
  import { get, isEqual } from 'lodash'
  import { RulesList } from 'vuntangle'
  import settingsMixin from '../settingsMixin'

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
          classes: this.classes,
        }),
        $features: {
          hasIpv6Support: true,
          hasClassCondition: true,
          hasLogAction: true,
        },
        $readOnly: false,
        $applications: {},
      }
    },

    props: {
      // the rule category type (e.g. `alert`, `trigger`)
      ruleType: { type: String, default: undefined },
    },
    data() {
      return {
        // Event rules config names
        eventRules: ['alert-rules'],
        /**
         * a map between rule type (alert rules, trigger rules), coming from route prop
         * and the rule configuration names mapped to the appliance settings
         * found in /vuntangle/src/shared/Conditions/data/rulesDefinitions.js
         */
        rulesMap: {
          'alert': ['alert-rules'],
        },
        classes: [],
      }
    },
    computed: {
      // translated main title of the view based on the rule type
      title: () => {},

      description: () => {},

      // the Class Fields for Event Rules Classes
      classFields: ({ $store }) => $store.getters['config/classFieldsData'],

      // rule configuration names associated with a given rule type
      ruleConfigs: ({ rulesMap, ruleType }) => rulesMap[ruleType],

      /**
       * Returns the actual rules extracted from settings based on each configuration
       * @param {Object} vm - vue instance
       * @param {Object} vm.settingsCopy - appliance settings
       * @param {Array<string>} vm.ruleConfigs - names of the configurations
       * @returns {Object} - with mapping between config name and the rules
       */
      rules: ({ settingsCopy, ruleConfigs, eventRules }) => {
        const rules = {}

        ruleConfigs.forEach(confName => {
          // For Network Settings Rules
          if (eventRules.includes(confName)) {
            rules[confName] = get(settingsCopy, confName.replace(/-/g, '_')) || []
          }
        })
        return rules
      },
    },

    created() {
      this.fetchClassFields()
    },

    methods: {
      /** Rules change listner, updates the settings */
      onRulesChange(updatedRules) {
        const newRules = updatedRules[this.ruleConfigs[0]]
        if (!isEqual(get(this.settingsCopy, this.ruleConfigs[0].replace(/-/g, '_')), newRules)) {
          this.settingsCopy[this.ruleConfigs[0].replace(/-/g, '_')] = newRules
          this.$emit('settings-change', this.settingsCopy, this.isDirty)
        }
      },

      fetchClassFields() {
        this.$store.commit('SET_LOADER', true)
        this.$store.dispatch('config/getClassFieldsData').finally(() => this.$store.commit('SET_LOADER', false))

        for (const className of Object.keys(this.classFields).sort()) {
          this.classes.push({
            text: className,
            value: '*' + className + '*',
            description: this.classFields[className].description,
          })
        }
      },
    },
  }
</script>
