<template>
  <div>
    <p class="font-weight-bold mt-6 mb-2">{{ $t('ipv6_aliases') }}</p>
    <em v-if="!list || !list.length" class="mr-2">{{ $t('no_aliases') }}</em>
    <v-chip v-for="(item, idx) in list" :key="idx" class="mr-1 mb-1" small close @click:close="onRemoveAlias(idx)">
      {{ item.staticAddress }}{{ item.staticPrefix || item.staticPrefix === 0 ? `/${item.staticPrefix}` : '' }}
    </v-chip>
    <v-chip v-if="!adding" class="mb-1" small color="primary" @click="adding = true">{{ $t('add_alias') }}</v-chip>

    <ValidationObserver v-slot="{ passes }" tag="div">
      <v-row v-if="adding" no-gutters align="center" class="mt-2">
        <v-col class="grow">
          <ValidationProvider v-slot="{ errors }" rules="required|ip_v6|unique_ip_v6_address">
            <u-text-field
              v-model="alias.staticAddress"
              :label="$t('address')"
              class="mr-2"
              :error-messages="errors"
              @keydown.space.prevent
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
        <v-col cols="3">
          <ValidationProvider v-slot="{ errors }" rules="min_value:1|max_value:128">
            <u-text-field
              v-model="alias.staticPrefix"
              :label="$t('prefix')"
              placeholder="1-128"
              type="number"
              :error-messages="errors"
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
        <v-col class="shrink">
          <u-btn icon :small="false" :min-width="null" class="primary mx-4" @click="passes(onAddAlias)">
            <v-icon color="white">mdi-check</v-icon>
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
  import cloneDeep from 'lodash/cloneDeep'
  import { extend } from 'vee-validate'
  import defaults from '../../defaults'

  export default {
    inject: ['$intf', '$interfaces', '$status'],

    props: {
      aliasKey: { type: Array, default: () => ['v6Aliases'] },
    },

    data({ $intf, $status }) {
      const intf = $intf()
      const status = $status()
      return {
        adding: false, // boolean telling to show the add fields
        alias: { ...defaults.v6_alias }, // model for new v6 alias
        // list: status?.[this.aliasKey].list?.length ? cloneDeep(intf[this.aliasKey].list) : [],
        list: intf?.[this.aliasKey]?.list ? cloneDeep(intf[this.aliasKey].list) : [],
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
          this.alias = { ...defaults.v6_alias }
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
        this.alias = { ...defaults.v6_alias }
      }
    },
    created() {
      extend('unique_ip_v6_address', this.validateUniqueIpV6Address)
    },
    methods: {
      /**
       * Make sure the IPv6 address of the alias being added does not conflict with any other
       * interfaces.
       *
       * @param {string} value
       *
       * @returns {string|boolean}
       */
      validateUniqueIpV6Address(value) {
        // check aliases from other network interfaces
        for (const networkInterface of this.interfaces) {
          // ignore current interface, those will be checked from the current editable data
          if (networkInterface.interfaceId === this.intf.interfaceId) {
            continue
          }

          // check v6 aliases
          if (networkInterface.v6Aliases?.length) {
            for (const v6Alias of networkInterface.v6Aliases) {
              if (v6Alias.staticAddress === value) {
                return this.$t('address_conflicts_with_interface', [networkInterface.name])
              }
            }
          }

          // check v6 static address
          if (networkInterface.v6StaticAddress === value) {
            return this.$t('address_conflicts_with_interface', [networkInterface.name])
          }
        }

        // check v6 addresses that are currently being added/edited on this interface
        for (const v6Alias of this.list) {
          if (v6Alias.staticAddress === value) {
            return this.$t('address_conflicts_with_current_interface')
          }
        }
        if (this.intf.v6StaticAddress === value) {
          return this.$t('address_conflicts_with_current_interface')
        }

        return true
      },
      onAddAlias() {
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
