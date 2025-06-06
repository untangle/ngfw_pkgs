<!--
  RuleAction is the generic component used for settings the action for a rule
  Actions are specific to each ruleType (`wan-policies`, `filter`, `nat`, `shaping` etc... )
-->
<template>
  <div v-if="actionCopy" class="d-flex gap-1">
    <!-- action type selector -->
    <ValidationProvider v-slot="{ errors }" rules="required">
      <u-select
        v-model="actionCopy.type"
        data-testid="actionType"
        :items="actionTypes"
        :placeholder="$vuntangle.$t(actionCopy.type.toLowerCase())"
        style="width: 360px"
        class="flex-grow-0 flex-shrink-0"
        :disabled="actionCopy.type === 'RETURN'"
        @change="onTypeChange"
      >
        <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
      </u-select>
    </ValidationProvider>

    <!-- `dnat_address` and `dnat_port` fields for DNAT action -->
    <ValidationProvider v-if="showDnatAddress" v-slot="{ errors }" rules="required|ip">
      <u-text-field
        v-model="actionCopy.dnat_address"
        data-testid="actionDnatAddress"
        :label="$vuntangle.$t('address')"
        :error-messages="errors"
      >
        <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
      </u-text-field>
    </ValidationProvider>
    <ValidationProvider v-if="showDnatAddress" v-slot="{ errors }" rules="port">
      <u-text-field
        v-model="actionCopy.dnat_port"
        data-testid="actionDnatPort"
        :label="$vuntangle.$t('port_optional')"
        :error-messages="errors"
        clearable
        style="width: 160px"
        @input="onDnatPortChange"
      >
        <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
      </u-text-field>
    </ValidationProvider>

    <!-- `snat_address` field for SNAT action -->
    <ValidationProvider
      v-if="showSnatAddress"
      v-slot="{ errors }"
      :rules="{ required: true, ip_expression: { multiple: false }, check_non_routeable_address: true }"
    >
      <u-text-field
        v-model="actionCopy.snat_address"
        data-testid="actionSnatAddress"
        :label="$vuntangle.$t('address')"
        :error-messages="errors"
      >
        <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
      </u-text-field>
    </ValidationProvider>

    <!-- `limit_exceed_action` field for LIMIT_EXCEED_ACTION action -->
    <ValidationProvider v-if="showLimitExceedAction" v-slot="{ errors }" rules="required" tag="div">
      <u-select
        v-model="actionCopy.limit_exceed_action"
        data-testid="actionLimitExceeded"
        :items="limitExceedActions"
        :placeholder="$vuntangle.$t('select')"
        :error-messages="errors"
        style="width: 200px"
        @change="onLimitExceedActionChange"
      >
        <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
      </u-select>
    </ValidationProvider>

    <!-- `priority` field for SET_PRIORITY or LIMIT_EXCEED_ACTION action -->
    <ValidationProvider v-if="showPriority" v-slot="{ errors }" rules="required" tag="div">
      <u-select
        v-model="actionCopy.priority"
        data-testid="actionPriority"
        :items="priorities"
        :placeholder="$vuntangle.$t('select')"
        :error-messages="errors"
      >
        <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
      </u-select>
    </ValidationProvider>

    <!-- `policy` field for WAN_POLICY action -->
    <ValidationProvider v-if="showWanPolicy" v-slot="{ errors }" rules="required" tag="div" class="flex-grow-1">
      <u-select
        v-model="actionCopy.policy"
        data-testid="actionWanPolicy"
        :items="remoteData.wanPolicies"
        :placeholder="$vuntangle.$t('select')"
        :label="$t('select')"
        :error-messages="errors"
      >
        <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
      </u-select>
    </ValidationProvider>
  </div>
</template>
<script>
  import { ValidationProvider } from 'vee-validate'
  import cloneDeep from 'lodash/cloneDeep'
  import isEqual from 'lodash/isEqual'
  import { priorityOptions, limitExceedActionOptions } from 'vuntangle'
  // import { priorityOptions, limitExceedActionOptions } from '../../constants'
  import { ruleDefs } from './data/rulesDefinitions'

  export default {
    components: { ValidationProvider },
    inject: ['$remoteData', '$features'],
    props: {
      action: { type: Object, default: undefined },
      rule: { type: Object, default: undefined },
      ruleType: { type: String, default: undefined },
    },
    data() {
      return {
        actionCopy: undefined,
      }
    },
    computed: {
      /**
       * Returns remoteData
       * @param {Object} vm - vue instance
       * @param {Function} vm.$remoteData - injected remote data
       */
      remoteData: ({ $remoteData }) => $remoteData(),

      // rule configuration based on it's type
      /**
       * Returns rule configuration based on it's type
       * @param {Object} vm - vue instance
       * @param {String} vm.ruleType - the rule type, e.g. `prioritization-rules`
       * @param {Object} vm.$features - injected features from host application
       */
      ruleDef: ({ ruleType, $features }) => {
        const def = cloneDeep(ruleDefs[ruleType])
        /**
         * below 6.1 limiting rules were added into prioritization chain
         * so we add the LIMIT_EXCEED_ACTION in such case
         */
        if (ruleType === 'prioritization-rules' && !$features.hasLimitingRules) {
          def.actions.push('LIMIT_EXCEED_ACTION')
        }
        return def
      },

      /**
       * Returns translated action type select field options in {text, value} form
       * @param {Object} vm - vue instance
       * @param {Object} vm.ruleDef - computed rule configuration
       * @param {String} vm.ruleType - rule type via props
       * @param {Object} vm.rule - actual rule via props
       * @param {Object} vm.$i18n - i18n engine
       */
      actionTypes: ({ ruleDef, ruleType, rule, $i18n }) => {
        let actionTypes = ruleDef.actions
        if (ruleType === 'limiting-rules') {
          // for limiting rules have to compute action based on limit rate condition operator
          const limitRateCondition = rule?.conditions?.find(cond => cond.type === 'LIMIT_RATE')
          if (limitRateCondition)
            actionTypes = limitRateCondition.op === '<' ? ['SET_PRIORITY'] : ['LIMIT_EXCEED_ACTION']
        }
        return actionTypes.map(action => ({
          text: $i18n.t(`rule_action_${action.toLowerCase()}`),
          value: action,
        }))
      },

      /**
       * Returns translated limit exceed actions select field options in {text, value} form
       * @param {Object} vm - vue instance
       * @param {Object} vm.$i18n - i18n engine
       */
      limitExceedActions: ({ $i18n }) =>
        limitExceedActionOptions.map(({ text, value }) => ({ text: $i18n.t(text), value })),

      /**
       * Returns translated priority field options in {text, value} form
       * @param {Object} vm - vue instance
       * @param {Object} vm.$i18n - i18n engine
       */
      priorities: ({ $i18n }) => priorityOptions.map(({ text, value }) => ({ text: $i18n.t(text), value })),

      // conditions to show extra action fields based on action type
      showDnatAddress: ({ actionCopy }) => actionCopy.type === 'DNAT',
      showDnatPort: ({ actionCopy }) => actionCopy.type === 'DNAT',
      showSnatAddress: ({ actionCopy }) => actionCopy.type === 'SNAT',
      showLimitExceedAction: ({ actionCopy }) => actionCopy.type === 'LIMIT_EXCEED_ACTION',
      showPriority: ({ actionCopy }) =>
        actionCopy.type === 'SET_PRIORITY' ||
        (actionCopy.type === 'LIMIT_EXCEED_ACTION' && actionCopy.limit_exceed_action === 'PRIORITY'),
      showWanPolicy: ({ actionCopy }) => actionCopy.type === 'WAN_POLICY',
    },

    watch: {
      action: {
        handler(newAction, oldAction) {
          if (isEqual(newAction, oldAction)) return
          this.actionCopy = cloneDeep(this.action)
        },
        deep: true,
        immediate: true,
      },
      actionCopy: {
        handler(action) {
          // upon action changes, emit update on parent dialog component
          this.$emit('update:action', action)
        },
        deep: true,
      },
    },

    methods: {
      /**
       * Adds or removes the `snat_address` field based on type
       * @param {String} type - action type
       */
      onTypeChange(type) {
        if (type === 'MASQUERADE') this.$delete(this.actionCopy, 'snat_address')
        if (type === 'SNAT') this.$set(this.actionCopy, 'snat_address', '')
      },

      /**
       * Adds or removes the `priority` field based on limit exceed action type
       * @param {String} limitExceedAction - action type
       */
      onLimitExceedActionChange(limitExceedAction) {
        if (limitExceedAction !== 'PRIORITY') this.$delete(this.actionCopy, 'priority')
        else this.$set(this.actionCopy, 'priority', 20)
      },

      /**
       * Removes the optional `dnat_port` field if null/empty
       * It gets added back upon editing
       * * @param {String} port - port number
       */
      onDnatPortChange(port) {
        if (!port) this.$delete(this.actionCopy, 'dnat_port')
      },
    },
  }
</script>
