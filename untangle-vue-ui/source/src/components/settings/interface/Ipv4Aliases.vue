<template>
  <div>
    <p class="font-weight-bold mt-6 mb-2">{{ $t('ipv4_aliases') }}</p>
    <em v-if="!list || !list.length" class="mr-2">{{ $t('no_aliases') }}</em>
    <v-chip v-for="(item, idx) in list" :key="idx" class="mr-1 mb-1" small close @click:close="onRemoveAlias(idx)">
      {{ item.v4Address }}{{ item.v4Prefix || item.v4Prefix === 0 ? `/${item.v4Prefix}` : '' }}
    </v-chip>
    <v-chip v-if="!adding" class="mb-1" small color="primary" @click="adding = true">{{ $t('add_alias') }}</v-chip>

    <ValidationObserver v-slot="{ passes }" tag="div">
      <v-row v-if="adding" no-gutters align="center" class="mt-2">
        <v-col class="grow">
          <!-- v4Address -->
          <ValidationProvider v-slot="{ errors }" rules="required|ip|unique_ip_address">
            <u-text-field
              v-model="alias.v4Address"
              :label="$t('address')"
              class="mr-2"
              :error-messages="errors"
              @keydown.space.prevent
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
        <v-col class="grow">
          <!-- v4Prefix -->
          <ValidationProvider v-slot="{ errors }" rules="required">
            <ipv-4-prefix-autocomplete v-model="alias.v4Prefix" :min="1" :errors="errors" />
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
  import defaultConfig from '@/util/defaultValues'

  export default {
    props: {
      interfaceId: { type: Number, default: null },
      v4StaticAddress: { type: String, default: null },
      aliases: { type: Array, default: () => [] },
    },
    data() {
      return {
        adding: false, // boolean telling to show the add fields

        // model for new v4 alias
        alias: { ...defaultConfig.V4_ALIAS },

        list: this.aliases?.length ? cloneDeep(this.aliases) : [],
      }
    },
    watch: {
      adding(value) {
        if (!value) {
          // reset
          this.alias = { ...defaultConfig.V4_ALIAS }
        }
      },
      list: {
        deep: true,
        handler(newList) {
          this.$emit('update:aliases', newList)
        },
      },
    },
    created() {
      extend('unique_ip_address', this.validateUniqueIpAddress)
    },
    methods: {
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
        for (const networkInterface of this.$store.getters['settings/interfaces']) {
          // ignore current interface, those will be checked from the current editable data
          if (networkInterface.interfaceId === this.interfaceId) {
            continue
          }

          // check v4 aliases
          if (networkInterface.v4Aliases?.length) {
            for (const v4Alias of networkInterface.v4Aliases) {
              if (v4Alias.v4Address === value) {
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
          if (v4Alias.v4Address === value) {
            return this.$t('address_conflicts_with_current_interface')
          }
        }
        if (this.v4StaticAddress === value) {
          return this.$t('address_conflicts_with_current_interface')
        }

        return true
      },
      onAddAlias() {
        this.list.push(this.alias)
        this.adding = false
      },
      onRemoveAlias(index) {
        this.list.splice(index, 1)
      },
    },
  }
</script>
