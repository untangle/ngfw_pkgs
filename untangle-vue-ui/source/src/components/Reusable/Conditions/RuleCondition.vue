<template>
  <u-autocomplete
    v-if="!condition.conditionType"
    v-model="newConditionType"
    :items="conditionTypes"
    :placeholder="$vuntangle.$t('add_condition')"
    style="width: 360px"
    class="flex-grow-0 flex-shrink-0"
  />
  <div v-else class="d-flex gap-1 align-center">
    <!-- CONDITION TYPE -->
    <ValidationProvider v-slot="{ errors }" rules="required|validate_service">
      <u-autocomplete
        v-if="!isObsolete"
        v-model="conditionCopy.conditionType"
        data-testid="conditionType"
        :items="conditionTypes"
        :placeholder="$vuntangle.$t('condition')"
        :suffix="requiredConditionSuffix"
        :error-messages="errors"
        style="width: 360px"
        class="flex-grow-0 flex-shrink-0"
        :disabled="requiredCondition"
        @change="conditionCopy.value = ''"
      >
        <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
      </u-autocomplete>
      <u-text-field
        v-else
        :value="$t(conditionType.toLowerCase())"
        disabled
        style="width: 360px"
        class="flex-grow-0 flex-shrink-0"
      />
    </ValidationProvider>

    <!-- OPERATORS
      Operator selector behaving as follows:
      - using is, is not (==, !=) for string values of a given condition conditionType (default)
      - using all operators (==, !=, >, <, >=, <=) for numeric values of a specific condition conditionType
      - disabled if conditionType is not set
      - not shown if field is boolean
      Does not need a validator as the value is always set to a default
    -->
    <u-select
      v-if="conditionDef.field !== 'boolean'"
      v-model="conditionCopy.op"
      data-testid="conditionOperator"
      :items="conditionDef.ops || isOperatorOptions"
      :disabled="!conditionType || isObsolete"
      style="width: 200px"
      class="flex-grow-0 flex-shrink-0"
    >
      <template #selection="{ item }">{{ $vuntangle.$t(item.text) }}</template>
      <template #item="{ item }">{{ $vuntangle.$t(item.text) }}</template>
    </u-select>

    <!-- VALUE
      the condition value that can be entered using different input fields depending on the condition conditionType
      - by default it's a simple textfield
      - in case of application names/categories/ids it's an autocomplete field
      - in case of application productivity/risk it's a select field
      see data/defs.js for each condition conditionType definition, the conditionType of input field

      SOURCE_PORT and DESTINATION_PORT conditions have an extra field `portProtocols`
      based on that, the value field size is shorter to make space for port protocols selector
    -->

    <!--
        default input text for string value of condition conditionTypes
        used for conditions that does not have a specific field defined
        see (data/defs.js)
        - disabled if condition conditionType is not set
        - using default `required` validation rule, along with other rules if specified in condition definition
      -->
    <ValidationProvider
      v-if="!conditionDef.field"
      v-slot="{ errors }"
      :rules="valueValidationRules"
      tag="div"
      class="flex-grow-1"
    >
      <u-text-field
        v-model="value"
        data-testid="conditionValue"
        :disabled="!conditionType || isObsolete"
        :placeholder="$vuntangle.$t('value')"
        :suffix="valueSuffix"
        :error-messages="errors"
      >
        <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
      </u-text-field>
    </ValidationProvider>

    <!-- select field
        used for conditions conditionTypes that have defined the value field being `select`
        - using the `selectItems` from the condition definition as the possible values for the condition value
        - disabled if condition conditionType not set
        see (data/defs.js)
      -->

    <ValidationProvider
      v-if="conditionDef.field === 'select'"
      v-slot="{ errors }"
      rules="required"
      tag="div"
      class="flex-grow-1"
    >
      <u-select
        v-model="value"
        data-testid="conditionValue"
        :items="conditionDef.selectItems || remoteItems"
        :disabled="!conditionType || isObsolete"
        :placeholder="$vuntangle.$t('value')"
        :loading="remoteLoading"
        :error-messages="errors"
      >
        <template #selection="{ item }">{{ $vuntangle.$t(item.text) || item }}</template>
        <template #item="{ item }">{{ $vuntangle.$t(item.text) || item }}</template>
        <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
      </u-select>
    </ValidationProvider>
    <!-- autocomplete field
        used for conditions conditionTypes that have defined the value field being `autocomplete`
        the `autocompleteItems` are set via an event captured by the host app, triggering an API call than passes via props the values
        this field applies for APPLICATION_NAME, APPLICATION_CATEGORY and APPLICATION_ID condition conditionTypes
      -->
    <!-- <template v-if="conditionDef.field === 'autocomplete'"> -->
    <ValidationProvider
      v-if="conditionDef.field === 'autocomplete'"
      v-slot="{ errors }"
      rules="required"
      tag="div"
      class="flex-grow-1"
    >
      <u-autocomplete
        v-model="value"
        data-testid="conditionValue"
        :items="conditionDef.autocompleteItems || remoteItems"
        :multiple="conditionDef.multiple"
        :placeholder="$vuntangle.$t('value')"
        :loading="remoteLoading"
        :error-messages="errors"
        :disabled="isObsolete"
      >
        <template #selection="{ item, index }">
          <span v-if="conditionType.startsWith('APPLICATION_CATEGORY')">
            {{ $vuntangle.$t(item.replace(/ /g, '_').toLowerCase()) }}
          </span>
          <span v-if="conditionType.startsWith('APPLICATION_NAME')">
            {{ item }}
          </span>
          <span v-if="conditionDef.multiple">
            <span v-if="index < othersIndex" class="mr-1">
              {{
                (item.text ? ($te(item.text) ? $t(item.text) : item.text) : item) +
                (value.length - 1 > index ? ',' : '')
              }}
            </span>

            <span v-if="index === othersIndex">
              {{ $t('x_others', [value.length - othersIndex]) }}
            </span>
          </span>
          <span v-else>{{ $te(item.text) ? $t(item.text) : item.text }}</span>
        </template>
        <template #item="{ item, attrs, on }">
          <v-list-item v-slot="{ active }" v-bind="attrs" dense class="px-2" v-on="on">
            <v-list-item-action v-if="conditionDef.multiple" class="my-0 mr-2">
              <v-checkbox :input-value="active" dense :ripple="false" />
            </v-list-item-action>
            <v-list-item-content v-if="conditionType === 'APPLICATION_CATEGORY'">
              {{ $vuntangle.$t(item.replace(/ /g, '_').toLowerCase()) }}
            </v-list-item-content>
            <v-list-item-content v-else> {{ item.text || item }} </v-list-item-content>
          </v-list-item>
        </template>
        <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
      </u-autocomplete>
    </ValidationProvider>

    <div v-if="conditionDef.field === 'boolean'" class="flex-grow-1">
      <v-radio-group v-model="value" data-testid="conditionValue" row class="mx-2 my-0 pa-0" hide-details>
        <v-radio :label="$vuntangle.$t('yes')" :value="'true'" :ripple="false" />
        <v-radio :label="$vuntangle.$t('no')" :value="'false'" :ripple="false" />
      </v-radio-group>
    </div>

    <!--
      SOURCE_PORT and DESTINATION_PORT conditions have an extra field `portProtocols`
      the below select field is used only for this specific case
    -->
    <ValidationProvider
      v-if="conditionType === 'SOURCE_PORT' || conditionType === 'DESTINATION_PORT'"
      v-slot="{ errors }"
      rules="required"
      tag="div"
      class="flex-grow-1"
    >
      <u-select
        v-model="portProtocols"
        data-testid="conditionPortProtocols"
        :placeholder="$vuntangle.$t('select_protocol')"
        :items="portProtocolOptions"
        :menu-props="{ offsetY: true }"
        :error-messages="errors"
        multiple
        :disabled="isObsolete"
      >
        <template #item="{ item, attrs, on }">
          <v-list-item v-slot="{ active }" dense v-bind="attrs" class="px-2" v-on="on">
            <v-list-item-action class="my-0 mr-2">
              <v-checkbox :input-value="active" dense :ripple="false" />
            </v-list-item-action>
            <v-list-item-content> {{ item.text }} </v-list-item-content>
          </v-list-item>
        </template>
        <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
      </u-select>
    </ValidationProvider>

    <template v-if="conditionType === 'LIMIT_RATE'">
      <ValidationProvider v-slot="{ errors }" rules="required">
        <u-select
          v-model="conditionCopy.rate_unit"
          data-testid="conditionValueRateUnit"
          :placeholder="$vuntangle.$t('select_unit')"
          :items="limitRateUnitOptions"
          :error-messages="errors"
          :disabled="isObsolete"
        >
          <template #selection="{ item }">{{ $vuntangle.$t(item.text) }}</template>
          <template #item="{ item }">{{ $vuntangle.$t(item.text) }}</template>
          <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
        </u-select>
      </ValidationProvider>
    </template>

    <v-btn :disabled="requiredCondition" icon class="ml-2" @click="$emit('delete-condition', conditionIndex)">
      <v-icon>mdi-close</v-icon>
    </v-btn>
  </div>
</template>
<script>
  import { VListItem, VListItemAction, VListItemContent, VCheckbox, VRadioGroup, VRadio } from 'vuetify/lib'
  import { ValidationProvider, extend } from 'vee-validate'

  import cloneDeep from 'lodash/cloneDeep'
  import isEqual from 'lodash/isEqual'
  import { UAutocomplete, limitRateUnitOptions, limitBurstUnitOptions } from 'vuntangle'
  import { conditionDefs } from './data/conditionsDefinitions'
  import { ruleDefs } from './data/rulesDefinitions'
  import { isOperatorOptions, portProtocolOptions } from '@/constants/index'

  export default {
    components: {
      VListItem,
      VListItemAction,
      VListItemContent,
      VCheckbox,
      VRadioGroup,
      VRadio,
      ValidationProvider,
      UAutocomplete,
    },
    inject: ['$remoteData', '$features'],
    props: {
      condition: { conditionType: Object, default: () => {} },
      ruleType: { conditionType: String, default: undefined },
      conditionIndex: { conditionType: Number, default: undefined },
      ruleConditions: { conditionType: Array, default: () => [] },
    },
    data() {
      return {
        conditionCopy: undefined,
        portProtocolOptions,
        isOperatorOptions,
        limitRateUnitOptions,
        limitBurstUnitOptions,
        newConditionType: '',
        remoteLoading: false,
        othersIndex: 5,
      }
    },
    computed: {
      /**
       * Returns remoteData from the host application
       * Check /mfw_ui/src/components/rules/RulesList.vue for details on injected data
       * @param {Object} vm - vue instance
       * @param {Function<Object>} vm.$remoteData - injected remoteData from host application
       */
      remoteData: ({ $remoteData }) => $remoteData(),

      /**
       * Returns a shorthand for the condition conditionType
       * @param {Object} vm - vue instance
       * @param {Object} conditionCopy - condition being edited
       */
      conditionType: ({ conditionCopy }) => conditionCopy.conditionType,

      /**
       * Returns condition definition as found in
       * /src/shared/Conditions/data/conditionsDefinitions.js
       * @param {Object} vm - vue instance
       * @param {String} vm.conditionType - the condition conditionType
       * @param {Object} vm.$features - injected features from host app
       */
      conditionDef: ({ conditionType, $features }) => {
        const condDef = conditionDefs[conditionType] || {}

        /**
         * according to CD-6091 which states that management interface conditionType not implemented
         * in ./src/constants defs the 'management' conditionType has been excluded
         * meaning that below `if` does nothing
         * + `hasManagementIntf` is only passed via features from local ui & not from cloud
         */
        if ($features?.hasManagementIntf === false && conditionType?.includes('INTERFACE_TYPE')) {
          const mgmtIndex = condDef.selectItems.findIndex(i => i?.text === 'management')
          if (mgmtIndex !== -1) {
            delete condDef.selectItems[mgmtIndex]
          }
        }
        return condDef
      },

      /**
       * Returns rule definition as found in
       * /src/shared/Conditions/data/rulesDefinitions.js
       * @param {Object} vm - vue instance
       * @param {String} vm.ruleType - the rule conditionType
       * @param {Object} vm.$features - injected features
       */
      ruleDef: ({ ruleType, $features }) => {
        const def = cloneDeep(ruleDefs[ruleType])
        /**
         * below 6.1 limiting rules were added into prioritization chain
         * so we add the LIMIT_RATE & BURST_SIZE conditions
         */
        if (ruleType === 'prioritization-rules' && !$features.hasLimitingRules) {
          def.conditions.push('LIMIT_RATE', 'BURST_SIZE')
        }
        return def
      },

      /**
       * Returns options for the condition conditionType selector filtered based on
       * - condition conditionTypes the rule might have
       * - filter out already used conditions
       * - grouped by category: Source/Dest/Other
       * @param {Object} vm - vue instance
       * @param {Object} vm.conditionCopy - the edited condition
       * @param {String} vm.ruleDef - the rule definition
       * @param {Array<Object>} vm.ruleConditions - the existing conditions on this rule, passed via props
       * @param {Object} vm.$i18n - i18n instance
       * @param {Object} vm.$features - injected features from host app
       */
      conditionTypes: ({ conditionCopy, ruleDef, ruleConditions, $i18n, $features }) => {
        // for qosmos some of the condition conditionTypes have to be excluded (all inferred ones, productivity & risk)
        const excludedQosmosConditions = [
          'APPLICATION_CATEGORY_INFERRED',
          'APPLICATION_NAME_INFERRED',
          'APPLICATION_PRODUCTIVITY',
          'APPLICATION_PRODUCTIVITY_INFERRED',
          'APPLICATION_RISK',
          'APPLICATION_RISK_INFERRED',
        ]

        // all available conditions for a given rule
        let allTypes = ruleDef?.conditions

        if ($features.hasQosmos) {
          allTypes = allTypes.filter(conditionType => !excludedQosmosConditions.includes(conditionType))
        }

        // map of existing conditions already added to the rule, except the one which is selected
        const existing = ruleConditions
          .map(cond => cond.conditionType)
          .filter(conditionType => conditionType !== conditionCopy?.conditionType)
        // filter out those existing conditions
        const conditionTypes = allTypes.filter(t => !existing.includes(t))
        // create groups of condition conditionTypes based on their dedicated category, e.g. source, destination
        const groups = {}

        conditionTypes.forEach(conditionType => {
          const condDef = conditionDefs[conditionType]
          // filter out condition conditionTypes above Layer 3 (for EOS)
          if ($features?.hasAboveLayer3Conditions === false && condDef.layer3 === false) return
          if (!groups[condDef.category]) groups[condDef.category] = [conditionType]
          else groups[condDef.category].push(conditionType)
        })

        // build out select component options ({ text, value}) based on above groups
        const options = []
        Object.entries(groups).forEach(([group, conditionTypes]) => {
          options.push({
            header: $i18n.t(group),
          })
          conditionTypes.forEach(conditionType => {
            options.push({
              text: $i18n.t(conditionType.toLowerCase()),
              value: conditionType,
            })
          })
        })
        return options
      },

      /**
       * Returns true/false if some already existing condition is no longer found in rule definitions
       * This is mostly used for deprecated conditions which might still be present on some rules
       * When true it will disable all condition fields
       * @param {Object} vm - vue instance
       * @param {String} vm.conditionType - the condition conditionType
       * @param {Object} vm.ruleDef - the rule definition
       */
      isObsolete: ({ conditionType, ruleDef }) => !ruleDef.conditions.includes(conditionType),

      /**
       * Returns validation rules for the condition value field
       * By default value field is required, but for some specific conditionTypes extra validators are added from condition definition
       * @param {Object} vm - vue instance
       * @param {String} vm.conditionType - the condition conditionType
       * @param {Object} vm.conditionDef - the condition definition
       */
      valueValidationRules: ({ conditionType, conditionDef }) =>
        conditionType ? `required|${conditionDef.extraRules || ''}` : '',

      /**
       * gets/sets the condition value needed to treat a special case for IP_PROTOCOL condition
       * settings.json accepts for IP_PROTOCOL a comma separated string with values
       * the autocomplete field returns an array of string values
       * so it has to do this get/set conversion for the condition value
       */
      value: {
        get: ({ conditionType, conditionCopy }) =>
          conditionCopy.value && (conditionType === 'IP_PROTOCOL' || conditionType === 'PROTOCOL')
            ? (conditionCopy.value + '').split(',')
            : conditionCopy.value,
        set(value) {
          if (this.conditionType === 'IP_PROTOCOL' || this.conditionType === 'PROTOCOL')
            this.conditionCopy.value = value.join() || null
          else this.conditionCopy.value = value
        },
      },

      /**
       * returns items for autocomplete/select fields conditions
       * retrieved from remote (host app)
       */

      /**
       * Returns select/autocomplete field options as [{ text, value }] or Array<String>
       * @param {Object} vm - vue instance
       * @param {String} vm.conditionType - the condition conditionType
       * @param {Object} vm.remoteData - the remoteData from host app
       */
      remoteItems: ({ conditionType, remoteData }) => {
        switch (conditionType) {
          case 'APPLICATION_NAME':
          case 'APPLICATION_NAME_INFERRED': {
            return remoteData?.classifyApplications?.map(app => app.name) || []
          }
          case 'APPLICATION_CATEGORY':
          case 'APPLICATION_CATEGORY_INFERRED': {
            return remoteData?.classifyApplications?.map(app => app.category) || []
          }
          case 'SOURCE_INTERFACE_ZONE':
            return remoteData?.interfaces.map(d => d.text) || []
          case 'DESTINATION_INTERFACE_ZONE':
          case 'CLIENT_INTERFACE_ZONE':
          case 'SERVER_INTERFACE_ZONE':
            return remoteData?.interfaces || []
          default:
            return undefined
        }
      },

      /**
       * sets the port protocol for DESTINATION or SOURCE port
       * for some reason the port protocol value can be a plain number or an array of numbers
       * so we have to switch between array or not depending of the single/multiple selection
       */
      portProtocols: {
        get: ({ conditionCopy }) =>
          !Array.isArray(conditionCopy?.port_protocol) ? [conditionCopy?.port_protocol] : conditionCopy?.port_protocol,
        set(value) {
          if (value.length === 1) this.conditionCopy.port_protocol = value[0]
          else this.conditionCopy.port_protocol = value
        },
      },

      /**
       * Returns true for LIMIT_RATE action in limiting rules
       * @param {Object} vm - vue instance
       * @param {String} vm.ruleType - the rule conditionType
       * @param {String} vm.conditionType - the condition conditionType
       */
      requiredCondition: ({ ruleType, conditionType }) =>
        ruleType === 'limiting-rules' && conditionType === 'LIMIT_RATE',

      /**
       * Returns a string denoting a required condition (e.g. LIMIT_RATE for limiting rules)
       * Is set as suffix on condition select field
       * @param {Object} vm - vue instance
       * @param {Object} vm.conditionDef - the condition definition
       * @param {Object} vm.$i18n - i18n engine
       */
      requiredConditionSuffix: ({ requiredCondition, $i18n }) =>
        requiredCondition ? `*${$i18n.t('required_condition')}` : null,

      /**
       * Returns a string suffix shown in value field
       * For now this is used just to show burst unit for BURST_SIZE condition
       * @param {Object} vm - vue instance
       * @param {String} vm.conditionType - the condition conditionType
       * @param {Object} vm.conditionCopy - the edited condition
       * @param {Object} vm.$i18n - i18n engine
       */
      valueSuffix: ({ conditionType, conditionCopy, $i18n }) =>
        conditionType === 'BURST_SIZE' && conditionCopy.burst_unit
          ? $i18n.t(conditionCopy.burst_unit.toLowerCase())
          : null,
    },

    watch: {
      condition: {
        // sets conditionCopy upon condition prop change
        handler(newCond, oldCond) {
          if (newCond.conditionType === 'BURST_SIZE') {
            this.$emit('add-limit-rate')
          }

          if (isEqual(newCond, oldCond)) return
          this.conditionCopy = cloneDeep(newCond)
        },
        immediate: true,
      },

      // updates some condition props based on conditionType
      conditionType: {
        handler(conditionType) {
          if (!conditionType) return
          if (conditionType === 'DST_PORT' || conditionType === 'PROTOCOL')
            this.conditionCopy.op = this.conditionCopy.invert ? '!=' : '=='

          /**
           * for some conditions data is retrieved from the host app
           * so an event is triggered to fetch that data
           */
          if (
            (conditionType.startsWith('APPLICATION_NAME') || conditionType.startsWith('APPLICATION_CATEGORY')) &&
            !this.remoteData?.classifyApplications?.length
          ) {
            this.$emit('fetch-classify-apps')
          }

          // for SOURCE_PORT and DESTINATION_PORT it adds/removes the extra `port_protocol`
          if (conditionType === 'SOURCE_PORT' || conditionType === 'DESTINATION_PORT') {
            if (!this.conditionCopy.port_protocol) {
              this.$set(this.conditionCopy, 'port_protocol', '6') // TCP by default as port_protocol is required
            }
          } else {
            this.$delete(this.conditionCopy, 'port_protocol')
          }

          // when adding BURST_SIZE condition and LIMIT_RATE condition already exists, set it's unit based on that
          if (conditionType === 'BURST_SIZE') {
            const limitRateCondition = this.ruleConditions.find(cond => cond.conditionType === 'LIMIT_RATE')
            this.conditionCopy.burst_unit = limitRateCondition?.rate_unit.split('_')[0] || 'PACKETS'
          }
        },
        immediate: true,
      },

      /**
       * updates the parent condition upon changes made
       */
      conditionCopy: {
        handler(cond) {
          this.$emit('update:condition', cond)
        },
        deep: true,
        immediate: true,
      },

      /**
       * Tracks newConditionType used in conditionType selector, to add a new condition when set
       */
      newConditionType(val) {
        if (val) {
          this.$emit('add-condition', val)
          this.newConditionType = undefined
        }
      },

      /**
       * This is a watcher to track the change event for limit rate unit
       * @param {String} value - the limit rate unit
       */
      'conditionCopy.rate_unit': {
        handler(value) {
          if (!value) return
          // emit event to update BURST_SIZE condition unit
          this.$emit('set-burst-unit', value)
        },
        immediate: true,
      },

      /**
       * Tracks condition operator and emits limit rule action change for LIMIT_RATE condition
       * @param {String} value - the limit rate unit
       */
      'conditionCopy.op': {
        handler(value) {
          if (this.conditionType !== 'LIMIT_RATE') return
          // emit event to update LIMIT_RATE condition action based on GREATER or LESS
          this.$emit('set-limit-rule-action', value)
        },
      },
    },

    created() {
      // add extra validator for conditions requiring a specific service to be running
      extend('validate_service', this.validateService)
    },

    methods: {
      /**
       * Custom validator extender used for services
       * @param {string} value - the condition conditionType
       */
      validateService(value) {
        if (!this.remoteData?.serviceStatus) return true
        // checks if the selected condition has the requied service enabled.
        // e.g: for selecting condition: "Application Category", service: "Application Control" should be enabled
        if (value.includes('APPLICATION') && this.remoteData && !this.remoteData.serviceStatus.application_control) {
          return this.$t('service_x_is_disabled', [this.$t('application_control')])
        }
        if (value === 'GEOIP' && this.remoteData && !this.remoteData.serviceStatus.geoip) {
          return this.$t('service_x_is_disabled', [this.$t('geoip')])
        }
        return true
      },
    },
  }
</script>
