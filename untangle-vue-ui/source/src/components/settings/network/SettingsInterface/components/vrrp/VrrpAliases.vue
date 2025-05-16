<template>
  <div>
    <p class="font-weight-bold mt-6 mb-2">{{ $t('VRRP Aliases') }}</p>
    <em v-if="!list || !list.length" class="mr-2">{{ $t('No VRRP Aliases defined') }}</em>
    <v-chip v-for="(item, idx) in list" :key="idx" class="mr-1 mb-1" small close @click:close="onRemoveAlias(idx)">
      {{ item.staticAddress }}{{ item.staticPrefix || item.staticPrefix === 0 ? `/${item.staticPrefix}` : '' }}
    </v-chip>
    <v-chip v-if="!adding" class="mb-1" small color="primary" @click="adding = true">{{ $t('add_alias') }}</v-chip>

    <ValidationObserver v-slot="{ passes }" tag="div">
      <v-row v-if="adding" no-gutters align="center" class="mt-2">
        <v-col class="grow">
          <!-- staticAddress -->
          <ValidationProvider v-slot="{ errors }" rules="required">
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
        <v-col class="grow">
          <!-- staticPrefix -->
          <ValidationProvider v-slot="{ errors }" rules="required">
            <u-text-field
              v-model="alias.staticPrefix"
              :label="$t('prefix')"
              placeholder="1-32"
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
  import defaults from '../../defaults'
  import Util from '../../../../../../util/setupUtil'
  export default {
    inject: ['$intf', '$interfaces'],
    props: {
      /**
       * the key under `interface` settings.json where aliases are going to be set
       * e.g.
       * `staticAddress` for vrrp settings
       * `vrrpAliases` for VRRP
       * */
      aliasKey: { type: String, default: 'vrrpAliases' },
    },
    data({ $intf }) {
      const intf = $intf()
      return {
        adding: false, // boolean telling to show the add fields
        alias: { ...defaults.vrrp_alias }, // model for new vrrp alias
        list: intf?.[this.aliasKey]?.list?.length ? cloneDeep(intf[this.aliasKey].list) : [],
      }
    },
    computed: {
      intf: ({ $intf }) => $intf(),
      interfaces: ({ $interfaces }) => $interfaces(),
    },
    watch: {
      adding(value) {
        if (!value) {
          // reset
          this.alias = { ...defaults.vrrp_alias }
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
    methods: {
      onAddAlias() {
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
