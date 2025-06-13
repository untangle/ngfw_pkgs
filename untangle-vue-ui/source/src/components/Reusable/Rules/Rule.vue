<template>
  <v-container :fluid="classicView">
    <div class="d-flex align-center">
      <h1 v-if="classicView" class="headline">{{ title }}</h1>
      <h2 v-else class="font-weight-light">{{ title }}</h2>
      <v-spacer />
      <!-- #action slot used in parent component for action buttons -->
      <slot name="actions" :updated-rule="ruleCopy"></slot>
    </div>

    <v-divider class="my-2" />

    <p
      class="body-2 my-4"
      v-html="ruleType !== 'bypass' ? $vuntangle.$t('rule_info') : $vuntangle.$t('bypass_description')"
    />
    <ValidationObserver ref="obs">
      <component :is="!$slots['extra-fields'] ? 'div' : 'u-section'">
        <slot v-if="!!$slots['extra-fields']" name="extra-fields" />
        <ValidationProvider v-if="showDescription" v-slot="{ errors }" rules="required" tag="div" class="flex-grow-1">
          <u-text-field
            v-model="ruleCopy.description"
            :placeholder="$vuntangle.$t('description')"
            :error-messages="errors"
            class="flex-grow-1"
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </component>

      <component :is="!$slots['extra-fields'] ? 'div' : 'u-section'">
        <v-row>
          <v-col class="d-flex">
            <v-checkbox v-model="ruleCopy.enabled" :label="$vuntangle.$t('rule_enabled')" hide-details />
          </v-col>
          <v-col v-if="ruleType === 'bypass' || ruleType === 'access' || ruleType === 'filter'" class="d-flex">
            <v-checkbox v-model="ruleCopy.log" :ripple="false" :label="$vuntangle.$t('log')" hide-details />
          </v-col>
        </v-row>

        <h3 class="mt-8 mb-2">{{ $vuntangle.$t('conditions') }}</h3>
        <p class="body-2" v-html="$vuntangle.$t('conditions_text')" />

        <u-alert v-if="!ruleCopy.conditions.length" class="body-2 mb-0 py-3">
          {{ $vuntangle.$t('no_conditions') }}
        </u-alert>
        <!-- using condition.type as an extra key composer -->
        <div
          v-for="(condition, i) in ruleCopy.conditions"
          :key="`${condition.type}-${i}`"
          class="d-flex align-center mb-2"
        >
          <rule-condition
            :condition.sync="ruleCopy.conditions[i]"
            :excluded-conditions="excludedConditions"
            :all-conditions.sync="ruleCopy.conditions"
            :box-settings="boxSettings"
            :features="features"
            v-bind="$props"
            @add-limit-rate="addLimitRate"
            @set-burst-unit="setBurstUnit"
            v-on="$listeners"
          />
          <v-btn icon class="ml-2" @click="onRemoveCondition(i)">
            <v-icon>mdi-close</v-icon>
          </v-btn>
        </div>

        <u-btn class="mt-2" @click="onAddCondition">{{ $vuntangle.$t('add_condition') }}</u-btn>

        <template v-if="ruleType !== 'bypass'">
          <h3 class="mt-8 mb-2">{{ $vuntangle.$t('action') }}</h3>
          <p class="body-2" v-html="$vuntangle.$t('action_text')" />
          <rule-action :action.sync="ruleCopy.action" :rule="ruleCopy" v-bind="$props" v-on="$listeners" />
        </template>
      </component>
    </ValidationObserver>
  </v-container>
</template>
<script>
  import { VContainer, VSpacer, VDivider, VCheckbox, VBtn, VIcon } from 'vuetify/lib'
  import cloneDeep from 'lodash/cloneDeep'
  import USection from '../../components/USection/USection.vue'
  import { RuleCondition, RuleAction } from '../Conditions'
  import { ruleDefs } from '../Conditions/data/rulesDefinitions'

  export default {
    components: {
      VContainer,
      VSpacer,
      VDivider,
      VCheckbox,
      VBtn,
      VIcon,

      USection,
      RuleCondition,
      RuleAction,
    },
    props: {
      title: { type: String, default: undefined },
      rule: { type: Object, default: () => {} },
      // the rule type, e.g. wan-rules
      ruleType: { type: String, default: undefined },
      remoteData: { type: Object, default: () => ({ apps: null, policies: null }) },
      remoteFetching: { type: Boolean, default: false },

      classicView: { type: Boolean, default: false },
      excludedConditions: { type: Array, default: null },
      // the settings applied on the box
      boxSettings: { type: Object, default: null },
      // used to show / hide the description field; shown for mfw-ui but hidden in ETM
      showDescription: { type: Boolean, default: true },
      features: { type: Object, default: null },
    },
    data: () => ({
      ruleCopy: undefined,
      ruleDef: undefined,
    }),

    watch: {
      rule: {
        handler(rule) {
          this.ruleDef = ruleDefs[this.ruleType]
          if (rule) {
            this.ruleCopy = cloneDeep(rule)
          } else {
            this.ruleCopy = cloneDeep(this.ruleDef.default)
          }
        },
        immediate: true,
      },
    },

    methods: {
      addLimitRate() {
        const limitRateIndex = this.ruleCopy.conditions.findIndex(condition => condition.type === 'LIMIT_RATE')
        const burstIndex = this.ruleCopy.conditions.findIndex(condition => condition.type === 'BURST_SIZE')

        if (limitRateIndex === -1) {
          // RATE_LIMIT condition does not exist add it 1 index before BURST_SIZE condition
          this.ruleCopy.conditions.splice(burstIndex, 0, {
            type: 'LIMIT_RATE',
            op: '<',
            value: undefined,
            rate_unit: 'PACKETS_PER_SECOND',
          })
        } else if (burstIndex - limitRateIndex !== 1) {
          // move RATE_LIMIT condition to one index before BURST_SIZE condition
          this.ruleCopy.conditions.splice(burstIndex, 0, this.ruleCopy.conditions.splice(limitRateIndex, 1)[0])
        }
      },

      /**
       * Sets the Burst condition unit in correlation with the Limit Rate unit
       * @param limitRateUnit - the LIMIT_RATE condition unit starting with: PACKETS_, BYTES_, KBYTES_ and MBYTES_
       */
      setBurstUnit(limitRateUnit) {
        // find the BURST_SIZE condition
        const index = this.ruleCopy.conditions.findIndex(condition => condition.type === 'BURST_SIZE')
        if (index === -1) return
        // if found make a clone to mutate
        const clonedBurstCondition = cloneDeep(this.ruleCopy.conditions[index])
        // set the burst unit based on limit rate unit
        this.$set(clonedBurstCondition, 'burst_unit', limitRateUnit.split('_')[0])
        // update burst condition
        this.ruleCopy.conditions.splice(index, 1, clonedBurstCondition)
      },

      onAddCondition() {
        this.ruleCopy.conditions.push({
          type: undefined,
          op: '==',
          value: undefined,
        })
      },

      /**
       * Removes a condition from rule at specified index
       * @param index - the condition index
       */
      onRemoveCondition(index) {
        // when removing LIMIT_RATE condition, make sure to remove BURST_SIZE condition first (if exists)
        if (this.ruleCopy.conditions[index]?.type === 'LIMIT_RATE') {
          const burstConditionIndex = this.ruleCopy.conditions.findIndex(cond => cond.type === 'BURST_SIZE')
          if (burstConditionIndex >= 0) this.$delete(this.ruleCopy.conditions, burstConditionIndex)
        }
        this.$delete(this.ruleCopy.conditions, index)
      },

      /**
       * validation called from parent component
       */
      async validate() {
        const isValid = await this.$refs.obs.validate()
        return isValid
      },
    },
  }
</script>
