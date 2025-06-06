<template>
  <v-container fluid class="d-flex flex-column flex-grow-1 pa-2">
    <!-- <policy-manager-alert :cloud-config-id="cloudConfigId" :cloud-disabled="cloudDisabled" /> -->
    <div :class="`shared-cmp d-flex flex-column flex-grow-1 ${cloudDisabled && 'disabled'}`">
      <div class="d-flex align-center">
        <h1 class="headline">{{ title }}</h1>
        <v-spacer />
        <slot name="actions" :updated-rules="rulesCopy" :is-dirty="isDirty"></slot>
      </div>

      <v-divider class="my-2" />
      <p class="body-2">
        <span v-if="description">{{ description }}<br /></span>
        {{ $vuntangle.$t('rules_executed_in_order') }}
      </p>

      <!-- extra-fields slot used for ETM global templates -->
      <slot name="extra-fields"></slot>

      <rules-grid
        v-for="(rulesList, ruleType) in rulesCopy"
        :key="ruleType"
        :rules="rulesList.list"
        :rule-type="ruleType"
        :show-rules-title="showRulesTitle"
        @edit-rule="onEditRule"
        @delete-rule="onDeleteRule"
        @update-order="rules => (rulesCopy[ruleType].list = rules)"
        v-on="$listeners"
      />

      <rule-dialog :rule.sync="editRule" :rule-type="editRuleType" @update-rule="onAddUpdateRule" v-on="$listeners" />
    </div>
  </v-container>
</template>
<script>
  import { VContainer, VSpacer, VDivider } from 'vuetify/lib'

  import cloneDeep from 'lodash/cloneDeep'
  import isEqual from 'lodash/isEqual'

  import util from '../../../util/util'
  // import PolicyManagerAlert from '../../policy-manager/components/PolicyManagerAlert.vue'
  import RuleDialog from './RuleDialog.vue'
  import RulesGrid from './RulesGrid.vue'

  export default {
    components: {
      VContainer,
      VSpacer,
      VDivider,
      RuleDialog,
      RulesGrid,
      // PolicyManagerAlert,
    },
    inject: ['$features'],
    props: {
      rules: { type: Object, default: () => {} },
      // the rule category type (e.g. `port-forward`, `shaping`, `nat`, `wan-rules`, `filter`, `access`, `bypass`)
      type: { type: String, default: undefined },
      title: { type: String, default: null },
      description: { type: String, default: null },
      cloudConfigId: { type: String, default: null },
      hasCloudPolicies: { type: Boolean, default: false },
    },
    data: () => ({
      rulesCopy: [],
      editRule: undefined,
      editRuleType: undefined,
    }),

    computed: {
      /**
       * Returns true if changes were made on any of the rules
       * @param {Object} vm - the vue instance
       * @param {Array} vm.rules - the original rules
       * @param {Array} vm.rulesCopy - the edited rules
       */
      isDirty: ({ rules, rulesCopy }) => !isEqual(rules, rulesCopy),

      /**
       * Whether to display rule chain name where there are multiple chains to be shown
       * e.g. for Shapin or Wan rules
       * @param {Object} vm - the vue instance
       * @param {Array} vm.rulesCopy - the edited rules
       */
      showRulesTitle: ({ rulesCopy }) => Object.keys(rulesCopy).length > 1,

      cloudDisabled: ({ cloudConfigId, hasCloudPolicies, type }) => {
        if (cloudConfigId) return true
        return hasCloudPolicies && ['filter', 'port-forward', 'shaping', 'nat'].includes(type)
      },
    },

    watch: {
      // emit rules update on change, needed for etm global bypass template
      rules: {
        immediate: true,
        handler(rules) {
          this.rulesCopy = cloneDeep(rules)
        },
      },
    },

    methods: {
      /**
       * Sets the edit rule and type which triggers showing the edit dialog
       * @param {Object} args
       * @param {Object} args.rule - the rule to be edited
       * @param {String} args.type - the rule type
       */
      onEditRule({ rule, type }) {
        this.editRuleType = type
        this.editRule = rule
      },

      /**
       * Removes a rule from the list
       * @param {Object} args
       * @param {String} args.id - the ruleId to be removed
       * @param {String} args.type - the rule type
       */
      onDeleteRule({ id, type }) {
        const ruleIndex = this.rulesCopy[type].list.findIndex(r => r.ruleId === id)
        if (ruleIndex >= 0) {
          this.rulesCopy[type].list.splice(ruleIndex, 1)
        }
      },

      /**
       * Add a new rule or updates an existing one
       * @param {Object} args
       * @param {Object} args.rule - the new or updated rule
       * @param {String} args.type - the rule type
       */
      onAddUpdateRule({ rule, type }) {
        const index = this.rulesCopy[type].list.findIndex(r => r.ruleId === rule.ruleId)
        if (index >= 0) {
          // if rule is found it gets updated with new changes
          this.rulesCopy[type].list.splice(index, 1, rule)
        } else {
          // if added it sets an uuid and gets added to the list
          rule.ruleId = util.uuidv4()
          this.rulesCopy[type].list.push(rule)
        }
        this.editRule = undefined
      },
    },
  }
</script>
