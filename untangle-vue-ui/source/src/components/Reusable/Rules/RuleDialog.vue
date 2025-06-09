<template>
  <v-dialog v-model="showDialog" attach=".v-main__wrap" content-class="rules-dialog" :transition="false">
    <v-card v-if="ruleCopy" class="d-flex flex-column flex-grow-1" outlined>
      <v-card-title class="text-h5 font-weight-light px-4">
        {{ ruleCopy.ruleId ? $t('edit_rule') : $t('add_rule') }}
        <v-spacer />
        <v-btn icon @click="$emit('update:rule', undefined)"><v-icon>mdi-close</v-icon></v-btn>
      </v-card-title>
      <ValidationObserver ref="obs">
        <v-card-text class="py-0">
          <div class="d-flex align-center">
            <ValidationProvider v-slot="{ errors }" rules="required" class="flex-grow-1">
              <u-text-field
                v-model="ruleCopy.description"
                :label="$vuntangle.$t('description')"
                :placeholder="$vuntangle.$t('description')"
                :error-messages="errors"
                class="mr-4"
                type="search"
              >
                <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
              </u-text-field>
            </ValidationProvider>
            <v-checkbox
              v-model="ruleCopy.enabled"
              :label="$vuntangle.$t('rule_enabled')"
              hide-details
              :ripple="false"
              class="ma-0 pa-0"
            />
            <v-checkbox
              v-if="withLogCheckbox"
              v-model="ruleCopy.log"
              :label="$vuntangle.$t('log')"
              hide-details
              :ripple="false"
              class="mx-4 my-0 pa-0"
            />
          </div>
        </v-card-text>

        <v-card-text class="flex-grow-1">
          <h3 class="ma-0">{{ $vuntangle.$t('conditions') }}</h3>
          <span class="body-2" v-html="$vuntangle.$t('conditions_text')" />

          <div style="height: 220px; overflow-y: auto" class="py-1">
            <div
              v-for="(condition, i) in ruleCopy.conditions.list"
              :key="`${condition.conditionType}-${i}`"
              class="mb-1"
            >
              <rule-condition
                :condition.sync="ruleCopy.conditions.list[i]"
                :condition-index="i"
                :rule-conditions.sync="ruleCopy.conditions.list"
                :rule-type="ruleType"
                @delete-condition="onDeleteCondition"
                @set-limit-rule-action="onSetLimitRuleAction"
                @set-burst-unit="onSetBurstUnit"
                v-on="$listeners"
              />
            </div>
            <div class="d-flex">
              <rule-condition
                :condition="newCondition"
                :rule-conditions.sync="ruleCopy.conditions.list"
                :rule-type="ruleType"
                @add-condition="onAddCondition"
              />
              <div class="ml-10"></div>
            </div>
          </div>
        </v-card-text>

        <v-card-text>
          <h3 class="ma-0">{{ $vuntangle.$t('action') }}</h3>
          <span class="body-2" v-html="$vuntangle.$t('action_text')" />
          <rule-action
            :action.sync="ruleCopy.action"
            :rule="ruleCopy"
            :rule-type="ruleType"
            class="pt-1"
            v-on="$listeners"
          />
        </v-card-text>
      </ValidationObserver>
      <v-card-actions class="pa-4 d-flex align-stretch">
        <v-spacer />
        <u-btn :small="false" text :min-width="80" @click="$emit('update:rule', undefined)">
          {{ $vuntangle.$t('cancel') }}
        </u-btn>
        <u-btn :small="false" :min-width="160" elevation="0" @click="onAction()">
          {{ ruleCopy.ruleId ? $vuntangle.$t('update_rule') : $vuntangle.$t('add_rule') }}
        </u-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>
<script>
  import cloneDeep from 'lodash/cloneDeep'
  import { RuleCondition, RuleAction } from '../Conditions'
  import { conditionDefs } from '../Conditions/data/conditionsDefinitions'
  import { javaClassMap, opToInvert } from '@/constants/index'

  export default {
    components: { RuleCondition, RuleAction },
    inject: ['$features'],
    props: {
      rule: { type: Object, default: () => undefined },
      ruleType: { type: String, default: undefined },
    },
    data() {
      return {
        ruleCopy: undefined,
        newCondition: { type: undefined },
      }
    },

    computed: {
      // shows the rule dialog when edit rule is set
      showDialog: {
        get: ({ ruleCopy }) => !!ruleCopy,
        set(value) {
          if (!value) this.$emit('update:rule', undefined)
        },
      },

      /**
       * Returns whether log checkbox should be present, usually for 6.1 and above
       * @param {Object} vm - vue instance
       * @param {String} vm.ruleType - the rule type
       * @param {Object} vm.$features - injected features from host app
       */
      withLogCheckbox: ({ ruleType, $features }) =>
        $features?.hasRuleLogs && ['access-rules', 'filter-rules', 'bypass-rules'].includes(ruleType),
    },

    watch: {
      rule: {
        handler(val) {
          this.ruleCopy = cloneDeep(val)
        },
        immediate: true,
      },
    },

    methods: {
      /**
       * Adds a new condition to the rule
       * @param {String} type - condition type
       */
      onAddCondition(conditionType) {
        // BURST_SIZE condition requires LIMIT_RATE condition to be also present
        if (conditionType === 'BURST_SIZE') {
          const limitRateIndex = this.ruleCopy.conditions.list.findIndex(
            condition => condition.conditionType === 'LIMIT_RATE',
          )
          if (limitRateIndex === -1) {
            this.ruleCopy.conditions.list.push({
              conditionType: 'LIMIT_RATE',
              op: '<',
              value: '',
              rate_unit: 'PACKETS_PER_SECOND',
            })
          }
        }

        const condition = {
          conditionType,
          ...(conditionDefs[conditionType]?.defaults || { op: '==', invert: false, value: '' }),
        }
        this.ruleCopy.conditions.list.push(condition)
        this.newCondition.conditionType = undefined
      },

      /**
       * Removes a condition from rule at specified index
       * @param {Number} index - the condition index
       */
      onDeleteCondition(index) {
        // when removing LIMIT_RATE condition, make sure to remove BURST_SIZE condition first (if exists)
        if (this.ruleCopy.conditions.list[index]?.type === 'LIMIT_RATE') {
          const burstConditionIndex = this.ruleCopy.conditions.list.findIndex(cond => cond.type === 'BURST_SIZE')
          if (burstConditionIndex >= 0) this.$delete(this.ruleCopy.conditions.list, burstConditionIndex)
        }
        this.$delete(this.ruleCopy.conditions.list, index)
      },

      /**
       * Sets limit rule action based on operator
       * @param {String} conditionOp - operator, less or greater than
       */
      onSetLimitRuleAction(conditionOp) {
        if (conditionOp === '>') {
          this.ruleCopy.action = { type: 'LIMIT_EXCEED_ACTION', limit_exceed_action: 'DROP' }
        }
        if (conditionOp === '<') {
          this.ruleCopy.action = { type: 'SET_PRIORITY', priority: this.ruleCopy.action.priority || 20 }
        }
      },

      /**
       * Sets the Burst condition unit in correlation with the Limit Rate unit
       * @param {String} limitRateUnit - the LIMIT_RATE condition unit starting with: PACKETS_, BYTES_, KBYTES_ and MBYTES_
       */
      onSetBurstUnit(limitRateUnit) {
        // find the BURST_SIZE condition
        const index = this.ruleCopy.conditions.list.findIndex(condition => condition.conditionType === 'BURST_SIZE')
        if (index === -1) return
        // if found make a clone to mutate
        const clonedBurstCondition = cloneDeep(this.ruleCopy.conditions.list[index])
        // set the burst unit based on limit rate unit
        this.$set(clonedBurstCondition, 'burst_unit', limitRateUnit.split('_')[0])
        // update burst condition
        this.ruleCopy.conditions.list.splice(index, 1, clonedBurstCondition)
      },

      /**
       * Validates the rule conditions and updates the rules list
       */
      async onAction() {
        const isValid = await this.$refs.obs.validate()
        if (!isValid) return
        this.ruleCopy = this.syncRuleData()

        this.$emit('update-rule', { rule: this.ruleCopy, type: this.ruleType })
      },

      /**
       * Syncs Data between backend model and vue model
       */
      syncRuleData() {
        const ruleCopy = this.ruleCopy
        // Update the rule object based on changes in action
        switch (ruleCopy.action?.type) {
          case 'DNAT':
            ruleCopy.newDestination = ruleCopy.action.newDestination
            ruleCopy.newPort = ruleCopy.action.newPort
            break

          default:
            break
        }
        ruleCopy.conditions.list.forEach(condition => {
          // Update invert/comparator based on condition operator value
          if ('op' in condition) {
            condition.invert = opToInvert[condition.op]
          }
          // Add javaClass if not present in each condition
          if (!('javaClass' in condition)) {
            condition.javaClass = javaClassMap[this.ruleType + '-condition']
          }
        })
        return ruleCopy
      },
    },
  }
</script>
