<template>
  <div class="d-flex flex-column flex-grow-1">
    <h3 v-if="showRulesTitle" class="font-weight-regular mt-4">{{ $t(conf.name) }}</h3>
    <u-grid
      :id="ruleType"
      :row-data="displayRules"
      :column-defs="columnDefs"
      custom-ordering
      :framework-components="frameworkComponents"
      :read-only="readOnlyGrid"
      :row-actions="rowActions"
      class="flex-grow-1"
      :custom-grid-options="{
        onRowDragEnd: updateRulesOrder,
      }"
      @row-clicked="showRuleDialog"
      v-on="$listeners"
    >
      <template #toolbarActions>
        <u-btn
          v-if="ruleType === 'command-center-rules'"
          :disabled="!etmNetworksUri"
          :href="etmNetworksUri"
          target="_blank"
          class="ml-4"
        >
          <v-icon small class="mr-2">mdi-open-in-new</v-icon>
          {{ $t('edit_in_etm') }}
        </u-btn>
        <u-btn v-else :disabled="$readOnly" class="ml-4" @click="showRuleDialog({ data: null })">
          <v-icon small class="mr-2">mdi-plus</v-icon>
          {{ $t('add_rule') }}
        </u-btn>
      </template>
    </u-grid>
  </div>
</template>
<script>
  import { ruleDefs } from 'vuntangle'

  import CheckboxRenderer from '../renderers/CheckboxRenderer.vue'
  import ConditionsRenderer from './ConditionsRenderer.vue'
  import ActionRenderer from './ActionRenderer.vue'
  import rulesGridMixin from './rulesGridMixin'

  export default {
    mixins: [rulesGridMixin],
    props: {
      rules: { type: Array, default: () => [] },
      ruleType: { type: String, default: undefined },
      showRulesTitle: { type: Boolean, default: undefined },
    },
    data() {
      return {
        frameworkComponents: { ConditionsRenderer, ActionRenderer, CheckboxRenderer },
      }
    },
    computed: {
      // do not show `isHidden` rules
      displayRules: ({ rules }) => rules?.filter(rule => !rule.isHidden),
      /**
       * Return rule configuration based on type
       * @param {Object} vm - vue instance
       * @param {Object} vm.ruleType - rule type via props
       */
      conf: ({ ruleType }) => ruleDefs[ruleType],

      /**
       * Returns column definitions fo rthe grid
       */
      columnDefs() {
        return [
          {
            colId: 'enabled-checkbox',
            headerName: this.$t('enabled'),
            field: 'enabled',
            width: 80,
            minWidth: 80,
            flex: 0,
            cellRenderer: 'CheckboxRenderer',
            cellRendererParams: { disabled: this.readOnlyGrid },
          },
          ...(this.$features.hasRuleLogs && ['access-rules', 'filter-rules', 'bypass-rules'].includes(this.ruleType)
            ? [
                {
                  colId: 'log-checkbox',
                  headerName: this.$t('log'),
                  field: 'log',
                  width: 80,
                  minWidth: 80,
                  flex: 0,
                  cellRenderer: 'CheckboxRenderer',
                  cellRendererParams: { disabled: this.readOnlyGrid },
                },
              ]
            : []),
          {
            colId: 'description',
            field: 'description',
            headerName: this.$t('description'),
            width: 320,
            minWidth: 320,
            flex: 0,
            autoHeight: true,
            wrapText: true,
          },
          {
            colId: 'conditions',
            field: 'conditions',
            headerName: this.$t('conditions'),
            flex: 1,
            autoHeight: true,
            wrapText: true,
            cellRenderer: 'ConditionsRenderer',
            valueGetter: ({ data }) => this.conditionsValue(data.conditions),
            valueFormatter: ({ value }) => JSON.stringify(value),
          },
          {
            colId: 'action',
            field: 'action',
            headerName: this.$t('action'),
            width: 400,
            minWidth: 400,
            flex: 0,
            autoHeight: true,
            wrapText: true,
            cellRenderer: 'ActionRenderer',
            valueGetter: ({ data }) => this.actionValue(data),
            valueFormatter: ({ value }) => JSON.stringify(value),
          },
        ]
      },

      /**
       * Flag if the grid is readonly
       * This is used on ETM appliance rules when appliance is offline and
       * Or for 'command-center' wan rules that should not be edited in local UI
       * @param {Object} vm - vue instance
       * @param {Object} vm.conf - computed rule configuration
       * @param {Boolean} vm.$readonly - injected readOnly state
       */
      readOnlyGrid: ({ conf, $readOnly }) => conf.disabled || $readOnly,

      /**
       * Returns row edit/delete actions if is not a readonly grid
       */
      rowActions() {
        return !this.readOnlyGrid
          ? [
              {
                icon: 'mdi-pencil',
                tooltip: this.$vuntangle.$t('edit'),
                handler: this.showRuleDialog,
              },
              {
                icon: 'mdi-delete',
                tooltip: this.$vuntangle.$t('remove'),
                handler: ({ data }) => this.$emit('delete-rule', { id: data.ruleId, type: this.ruleType }),
              },
            ]
          : []
      },
    },

    mounted() {
      /**
       * Triggers event to fetch networks URI from the box which sets it via injected $remoteData
       * used for Edit in ETM button
       */
      if (this.ruleType === 'command-center-rules') {
        this.$emit('fetch-networks-uri')
      }
    },

    methods: {
      /**
       * Handler when clicking on a row or edit row action button
       * @param {Object} event - the grid event
       * @param {Object} event.data - the rule row data
       */
      showRuleDialog({ data }) {
        // if grid is readonly do nothing
        if (this.readOnlyGrid) return

        let rule = this.rules.find(rule => rule.ruleId === data?.ruleId)
        if (!rule) {
          rule = this.conf.default
        }
        // edit rule is handled by the rules listing
        this.$emit('edit-rule', { rule, type: this.ruleType })
      },

      /**
       * Updates the rules order upon manual reordering
       * @param {Object} event - the grid event
       * @param {Object} event.api - the grid api
       */
      updateRulesOrder({ api }) {
        const newRulesOrder = []

        api.forEachNode(({ data }) => {
          newRulesOrder.push(data)
        })
        // edit rule is handled by the rules listing
        this.$emit('update-order', newRulesOrder)
      },
    },
  }
</script>
