<template>
  <div>
    <p class="font-weight-bold mt-6 mb-2">{{ $t('dhcp_options') }}</p>

    <em v-if="(intf.dhcpType === CONFIG_TYPE.SERVER && !list) || !list.length" class="mr-2">{{ $t('no_options') }}</em>
    <v-chip v-for="(item, idx) in list" :key="idx" class="mr-1 mb-1 ma-2" small close @click:close="onRemoveAlias(idx)">
      {{ item.enabled }}{{ item.description }}{{ item.value }}
    </v-chip>
    <u-btn v-if="!adding" x-small :small="false" :min-width="null" rounded @click="adding = true">
      {{ $t('add_option') }}
    </u-btn>
    <v-data-table dense :items="list" hide-default-footer calculate-widths class="mb-2">
      <template #[`item.enabled`]="{ item }">
        <v-simple-checkbox v-model="item.enabled" color="primary" hide-details class="ma-0" :ripple="false" />
      </template>
      <template #[`item.delete`]="{ index }">
        <v-btn icon small color="red darken-2" @click="list.splice(index, 1)"><v-icon>mdi-delete</v-icon></v-btn>
      </template>
    </v-data-table>

    <ValidationObserver v-slot="{ passes }" tag="div">
      <v-row v-if="adding" no-gutters align="center" class="mt-2">
        <v-col cols="1">
          <v-checkbox v-model="alias.enabled" hide-details />
        </v-col>
        <v-col class="grow">
          <ValidationProvider v-slot="{ errors }" rules="required">
            <u-text-field
              v-model="alias.description"
              :label="$t('description')"
              placeholder="[no description]"
              :error-messages="errors"
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
            <!-- </v-combobox> -->
          </ValidationProvider>
        </v-col>
        <v-col cols="4">
          <ValidationProvider v-slot="{ errors }" rules="required">
            <u-text-field v-model="alias.value" :label="$t('prefix')" :error-messages="errors">
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
  import { VDataTable, VSimpleCheckbox, VBtn, VIcon, VRow, VCol } from 'vuetify/lib'
  import cloneDeep from 'lodash/cloneDeep'
  import defaults from '../../defaults'
  import { CONFIG_TYPE } from '../constants'

  export default {
    components: { VDataTable, VSimpleCheckbox, VBtn, VIcon, VRow, VCol },
    inject: ['$intf', '$interfaces', '$status'],
    props: {
      aliasKey: { type: Array, default: () => ['dhcpOptions'] },
    },
    data({ $intf, $status }) {
      const intf = $intf()
      const status = $status()

      // Ensure dhcpOptions exists on the intf object
      if (!intf.dhcpOptions) {
        intf.dhcpOptions = {
          javaClass: 'java.util.LinkedList',
          list: [],
        }
      }
      return {
        adding: false, // boolean telling to show the add fields
        alias: { ...defaults.dhcp_options },
        // list: status?.[this.aliasKey].list?.length ? cloneDeep(intf[this.aliasKey].list) : [],
        list: status?.dhcpOptions?.list?.length ? cloneDeep(intf.dhcpOptions.list) : [],
        CONFIG_TYPE,
      }
    },
    computed: {
      intf: ({ $intf }) => $intf(),
      interfaces: ({ $interfaces }) => $interfaces(),
      status: ({ $status }) => $status(),
    },
    watch: {
      adding(value) {
        if (!value) {
          // reset
          this.alias = { ...defaults.dhcp_options }
        }
      },
      list: {
        deep: true,
        handler(newList) {
          this.$set(this.intf[this.aliasKey], 'list', newList)
        },
      },
    },
    mounted() {
      if (!this.intf.interfaceId && this.list.length === 0) {
        this.adding = true
        this.alias = { ...defaults.dhcp_options }
      }
    },
    methods: {
      onAddOption() {
        this.list.push({
          ...this.alias,
          markedForDelete: false,
          markedForNew: true,
        })
        this.adding = false
      },
      onRemoveAlias(index) {
        this.list.splice(index, 1)
      },
    },
  }
</script>
