<template>
  <div>
    <p class="font-weight-bold mt-6 mb-2">{{ $t('dhcp_options') }}</p>

    <em v-if="intf.dhcpType === CONFIG_TYPE.SERVER" class="mr-2">{{ $t('no_options') }}</em>
    <v-data-table dense :headers="headers" :items="list" hide-default-footer calculate-widths class="mb-2">
      <template #[`item.enabled`]="{ item }">
        <v-simple-checkbox v-model="item.enabled" color="primary" hide-details class="ma-0" :ripple="false" />
      </template>
      <template #[`item.delete`]="{ index }">
        <v-btn icon small color="red darken-2" @click="list.splice(index, 1)"><v-icon>mdi-delete</v-icon></v-btn>
      </template>
    </v-data-table>

    <u-btn v-if="!adding" x-small :small="false" :min-width="null" rounded @click="adding = true">
      {{ $t('add_option') }}
    </u-btn>

    <ValidationObserver v-slot="{ passes }" tag="div">
      <v-row v-if="adding" no-gutters align="center" class="mt-2">
        <v-col class="grow">
          <ValidationProvider v-slot="{ errors }" rules="required">
            <v-combobox
              v-model="dhcpOption"
              :items="dhcpOptions"
              dense
              outlined
              hide-details
              return-object
              :label="$t('select_option')"
              class="mr-2"
              :error-messages="errors"
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </v-combobox>
          </ValidationProvider>
        </v-col>
        <v-col cols="4">
          <ValidationProvider v-slot="{ errors }" rules="required">
            <u-text-field
              v-model="dhcpValue"
              :label="$t('value')"
              :error-messages="errors"
              :prefix="valuePrefix"
              :disabled="valuePrefix == null"
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
        <v-col class="shrink">
          <u-btn icon :small="false" :min-width="null" class="mx-2" @click="passes(onAddOption)">
            <v-icon>mdi-check</v-icon>
          </u-btn>
        </v-col>
        <v-col class="shrink">
          <u-btn icon :small="false" :min-width="null" @click="adding = false"><v-icon>mdi-close</v-icon></u-btn>
        </v-col>
      </v-row>
    </ValidationObserver>
  </div>
</template>
<script>
  import { VDataTable, VSimpleCheckbox, VBtn, VIcon, VRow, VCol, VCombobox } from 'vuetify/lib'
  import cloneDeep from 'lodash/cloneDeep'
  import defaults from '../../defaults'
  import { CONFIG_TYPE } from '../constants'

  export default {
    components: { VDataTable, VSimpleCheckbox, VBtn, VIcon, VRow, VCol, VCombobox },
    inject: ['$intf', '$interfaces'],
    props: {
      options: { type: Array, default: () => [] },
    },
    data() {
      return {
        intf: ({ $intf }) => $intf(),
        adding: false, // boolean telling to show the add fields
        dhcpOptions: defaults.dhcp_options,

        dhcpOption: null,
        dhcpValue: null,
        list: this.options?.length ? cloneDeep(this.options) : [],
        CONFIG_TYPE,
      }
    },
    computed: {
      // use prefix number if it exists, otherwise use empty string
      valuePrefix() {
        return this.dhcpOption ? (this.dhcpOption.value ? this.dhcpOption.value + ',' : '') : null
      },
      headers() {
        return [
          { text: this.$t('description'), value: 'description', sortable: false },
          { text: this.$t('value'), value: 'value', sortable: false },
          { text: this.$t('enabled'), align: 'center', value: 'enabled', sortable: false, width: 60 },
          { text: this.$t('remove'), align: 'center', value: 'delete', sortable: false, width: 60 },
        ]
      },
    },
    watch: {
      adding(value) {
        if (!value) {
          // reset
          this.dhcpOption = null
          this.dhcpValue = null
        }
      },
      list: {
        deep: true,
        handler(newList) {
          this.$emit('update:options', newList)
        },
      },
    },
    methods: {
      onAddOption() {
        let value
        let description
        // if dhcpOption is a string, use user provided input,
        // otherwise use template values
        if (typeof this.dhcpOption === 'string') {
          description = this.dhcpOption
          value = this.dhcpValue
        } else {
          description = this.dhcpOption.text
          value = `${this.dhcpOption.value},${this.dhcpValue}`
        }
        this.list.push({
          description,
          value,
          enabled: true,
        })
        this.adding = false
      },
    },
  }
</script>
