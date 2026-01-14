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
    @load-conditions="onLoadClassConditions"
    @rules-change="onRulesChange"
  ></rules-list>
</template>
<script>
  import { get, isEqual } from 'lodash'
  import { RulesList, conditionDefs } from 'vuntangle'
  import settingsMixin from '../settingsMixin'
  import {
    booleanOperatorOptions,
    booleanValueOptions,
    invertOptions,
    numericOptions,
    textOperatorOptions,
  } from '@/constants/index'

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
          classFields: this.classFields,
          conditions: this.conditions,
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

        /**
         * Object to store the class fields apu data stored systematically.
         * Provided to vuntangle components
         * Helps to dynamically set ruleDefs and conditionDefs conditions
         */
        classFields: [],

        // ruleDefs conditions. dynamically changed on class field change.
        conditions: [],

        // Default condition object for conditionDefs
        defaultCondition: {
          dynamic: true,
          extraRules: null,
          target: 'OTHER',
          field: null,
          ops: invertOptions,
          multiple: false,
          autocompleteItems: null,
          selectItems: null,
          defaults: {
            op: '=',
            value: '',
            javaClass: 'com.untangle.uvm.event.generic.EventRuleConditionGeneric',
          },
        },
      }
    },
    computed: {
      // translated main title of the view based on the rule type
      title: () => {},

      description: () => {},

      // the Class Fields for Event Rules Classes
      classFieldsData: ({ $store }) => $store.getters['config/classFieldsData'],

      // flag to denote that ruletype requires all classes option
      requireAllClasses: ({ ruleType }) => [].includes(ruleType),

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
          // For Event Settings Rules
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

    beforeDestroy() {
      this.removeDynamicConditions()
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
        const me = this
        for (const className of Object.keys(this.classFieldsData).sort()) {
          const conditionsMap = {}
          const conditionsOrder = []
          this.classFieldsData[className].fields.forEach(function (field) {
            const condition = {}
            const fieldNames = field.name.split('.')
            const ignoreFieldName = fieldNames[fieldNames.length - 1]
            if (ignoreFieldName === 'class' || ignoreFieldName === 'timeStamp') {
              return
            }

            condition.description = field.description
            if (field.values) {
              condition.field = 'select'
              condition.ops = booleanOperatorOptions
              condition.selectItems = field.values
            } else {
              switch (field.type.toLowerCase()) {
                case 'boolean':
                  condition.field = 'select'
                  condition.ops = booleanOperatorOptions
                  condition.selectItems = booleanValueOptions
                  break
                case 'double':
                case 'float':
                case 'integer':
                case 'int':
                case 'long':
                case 'short':
                  condition.extraRules = 'numeric'
                  condition.ops = numericOptions
                  break
                default:
                  condition.ops = textOperatorOptions
                  break
              }
            }

            const newCondition = Object.assign({}, me.defaultCondition, condition)
            conditionsMap[field.name] = newCondition
            conditionsOrder.push(newCondition.name)
          })

          this.classFields.push({
            text: className,
            value: '*' + className + '*',
            description: this.classFieldsData[className].description,
            conditions: conditionsMap,
            conditionsOrder,
          })
        }
        if (this.requireAllClasses)
          this.classFields.push({
            text: 'All',
            value: '*All*',
            description: 'Match all classes (NOT RECOMMENDED!)',
            conditions: {},
            conditionsOrder: [],
          })
      },

      /**
       * Based on classname selected updated the conditions
       * @param {String} className Selected clssname from rules dialog
       */
      onLoadClassConditions(className) {
        // Firt remove previous class conditions if any
        this.removeDynamicConditions()

        const classField = this.classFields.find(f => f.value === className)
        if (classField) {
          const conditionsMap = classField.conditions
          for (const key in conditionsMap) {
            conditionDefs[key] = conditionsMap[key]
          }
          this.conditions = Object.keys(conditionsMap)
        }
      },

      /**
       * Removes unnecessary conditions from conditionDefs
       */
      removeDynamicConditions() {
        this.conditions = Object.keys([])
        Object.keys(conditionDefs).forEach(function (key) {
          if (conditionDefs[key].dynamic === true) {
            this.$delete(conditionDefs, key)
          }
        }, this)
      },
    },
  }
</script>
