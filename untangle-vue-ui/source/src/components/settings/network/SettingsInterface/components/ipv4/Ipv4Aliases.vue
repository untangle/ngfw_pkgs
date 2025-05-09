<template>
  <div>
    <p class="font-weight-bold mt-6 mb-2">{{ $t('ipv4_aliases') }}</p>
    <em v-if="!list || !list.length" class="mr-2">{{ $t('no_aliases') }}</em>
    <v-chip v-for="(item, idx) in list" :key="idx" class="mr-1 mb-1" small close @click:close="onRemoveAlias(idx)">
      {{ item.staticAddress }}{{ item.staticPrefix || item.staticPrefix === 0 ? `/${item.staticPrefix}` : '' }}
    </v-chip>
    <v-chip v-if="!adding" class="mb-1" small color="primary" @click="adding = true">{{ $t('add_alias') }}</v-chip>

    <ValidationObserver v-slot="{ passes }" tag="div">
      <v-row v-if="adding" no-gutters align="center" class="mt-2">
        <v-col class="grow">
          <!-- staticAddress -->
          <ValidationProvider v-slot="{ errors }" rules="required|ip|unique_ip_address">
            <u-text-field
              v-model="alias.staticAddress"
              :label="$t('enter IPv4 address')"
              class="mr-2"
              :error-messages="errors"
              @keydown.space.prevent
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
        <v-col class="grow">
          <!-- staticPrefix -->
          <ValidationProvider v-slot="{ errors }" rules="required">
            <ipv-4-prefix-autocomplete
              v-model="alias.staticPrefix"
              :min="1"
              :errors="errors"
              @click:modelValue="onStaticPrefixChange"
            />
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
  import { Ipv4PrefixAutocomplete } from 'vuntangle'
  import defaults from '../../defaults'
  import Util from '../../../../../../util/setupUtil'

  export default {
    components: {
      Ipv4PrefixAutocomplete,
    },
    inject: ['$intf', '$interfaces', '$status'],

    props: {
      /**
       * the key under `interface` settings.json where aliases are going to be set
       * e.g.
       * `v4Aliases` for IPv4 settings
       * */
      aliasKey: { type: Array, default: () => ['v4Aliases'] },
    },

    data({ $intf, $status }) {
      const intf = $intf()
      const status = $status()
      return {
        adding: false, // boolean telling to show the add fields
        alias: { ...defaults.v4_alias }, // model for new v4 alias
        list: status?.[this.aliasKey].list?.length ? cloneDeep(intf[this.aliasKey].list) : [],
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
          this.alias = { ...defaults.v4_alias }
        }
      },
      list: {
        deep: true,
        handler(newList) {
          // using $set to maintain reactivity in case aliasKey not existing in interface settings
          this.$set(this.intf[this.aliasKey], 'list', newList)
        },
      },
    },
    created() {
      extend('unique_ip_address', this.validateUniqueIpAddress)
    },
    methods: {
      onStaticPrefixChange(prefix) {
        this.alias.staticNetmask = Util.getNetmask(prefix)
      },
      /**
       * Make sure the IPv4 address of the alias being added does not conflict with any other
       * interfaces.
       *
       * @param {string} value
       *
       * @returns {string|boolean}
       */
      validateUniqueIpAddress(value) {
        // check aliases from other network interfaces
        for (const networkInterface of this.interfaces) {
          // ignore current interface, those will be checked from the current editable data
          if (networkInterface.interfaceId === this.intf.interfaceId) {
            continue
          }
          // check v4 aliases
          if (networkInterface.v4Aliases?.length) {
            for (const v4Alias of networkInterface.v4Aliases) {
              if (v4Alias.staticAddress === value) {
                return this.$t('address_conflicts_with_interface', [networkInterface.name])
              }
            }
          }

          // check v4 static address
          if (networkInterface.v4StaticAddress === value) {
            return this.$t('address_conflicts_with_interface', [networkInterface.name])
          }
        }

        // check v4 addresses that are currently being added/edited on this interface
        for (const v4Alias of this.list) {
          if (v4Alias.staticAddress === value) {
            return this.$t('address_conflicts_with_current_interface')
          }
        }
        if (this.intf.v4StaticAddress === value) {
          return this.$t('address_conflicts_with_current_interface')
        }

        return true
      },
      onAddAlias() {
        this.alias.staticNetmask = Util.getNetmask(this.alias.staticPrefix)
        this.list.push({
          ...this.alias,
          staticNetmask: Util.getNetmask(this.alias.staticPrefix),
        })
        this.adding = false
      },
      onRemoveAlias(index) {
        this.list.splice(index, 1)
      },
    },
  }
</script>
