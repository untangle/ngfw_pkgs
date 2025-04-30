<template>
  <v-form :disabled="disabled" :class="{ 'shared-cmp disabled': disabled }">
    <ValidationObserver ref="common">
      <div class="d-flex align-center" style="gap: 48px">
        <v-spacer />
        <u-alert v-if="boundInterfaces" class="ma-0 py-2" info>
          <span v-html="$t('bound_wan_interface_warning', [boundInterfaces])"></span>
        </u-alert>
        <!-- delete action button, available for virtual interfaces only when editing -->
        <!-- <u-btn v-if="showDelete" text color="red" @click="$onDelete">
          {{ $t('delete_interface') }}
        </u-btn> -->
      </div>

      <v-row>
        <!-- name -->
        <v-col>
          <ValidationProvider v-slot="{ errors }" :rules="!isSaving ? interfaceNameRules : ''">
            <u-text-field v-model="intf.name" :label="$t('interface_name')" maxlength="400" :error-messages="errors">
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
        <!-- <v-col>
          <u-text-field v-model="configTypeTranslated" :label="$t('config_type')" />
        </v-col> -->

        <!-- boundInterfaceId -->
        <!-- <v-col v-if="showBoundToOptions">
          <ValidationProvider v-slot="{ errors }" rules="required">
            <u-select
              v-model="intf.boundInterfaceId"
              :items="boundToOptions"
              i-p-s-e-c
              :label="$t('bound_to')"
              :error-messages="errors"
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-select>
          </ValidationProvider>
        </v-col> -->
      </v-row>
      <v-row>
        <v-col>
          <span class="text font-weight-medium grey--text text--darken-2 ma-0 pa-0">Config Type</span>
          <v-radio-group v-model="intf.configType" row class="ma-0">
            <v-radio :value="CONFIG_TYPE.ADDRESSED" :label="$t(`Addressed`)" />
            <v-radio :value="CONFIG_TYPE.BRIDGED" :label="$t(`Bridged`)" />
            <v-radio :value="CONFIG_TYPE.DISABLED" :label="$t('disabled')" />
          </v-radio-group>
        </v-col>
      </v-row>

      <!-- bridgedTo -->
      <v-row v-if="isBridged && !intf.isWirelessInterface" class="mb-2">
        <v-col>
          <ValidationProvider v-slot="{ errors }" rules="required">
            <v-select
              v-model="intf.bridgedTo"
              :items="bridgedToOptions"
              :label="$t('bridged_to')"
              :error-messages="errors"
              attach
              small-chips
              deletable-chips
              dense
              outlined
              hide-details
              :placeholder="$vuntangle.$t('select')"
              :menu-props="{ offsetY: true, dense: true }"
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </v-select>
          </ValidationProvider>
        </v-col>
      </v-row>

      <v-row v-if="type === 'VLAN'">
        <!-- boundInterfaceId -->
        <v-col>
          <ValidationProvider v-slot="{ errors }" :rules="boundInterfaceIdRules">
            <u-select
              v-model="intf.boundInterfaceId"
              :items="boundToOptions"
              :label="$t('parent_interface')"
              :error-messages="errors"
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-select>
          </ValidationProvider>
        </v-col>

        <!-- vlanid -->
        <v-col>
          <ValidationProvider v-slot="{ errors }" :rules="vlanIdRules">
            <u-text-field v-model="intf.vlanid" :label="$t('vlan_id')" placeholder="1 - 4094" :error-messages="errors">
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
      </v-row>

      <div v-if="isAddressed" class="d-flex align-center" style="gap: 48px">
        <v-switch v-model="intf.isWan" :label="$t('wan_interface')" />

        <!-- natEgress -->
        <v-checkbox
          v-if="!intf.isWan"
          v-model="intf.v4NatIngressTraffic"
          :label="$t(`NAT traffic coming from this interface (and bridged peers)`)"
        />
        <v-checkbox
          v-if="intf.isWan"
          v-model="intf.v4NatEgressTraffic"
          :label="$t(`NAT traffic exiting this interface (and bridged peers)`)"
        />
      </div>
    </ValidationObserver>

    <!-- tabs navigation -->
    <div v-if="showTabs" class="d-flex flex-row align-center mt-8">
      <v-divider />
      <v-btn-toggle v-model="selectedTab" dense rounded mandatory>
        <v-btn
          v-for="tab in tabs"
          :key="tab.key"
          style="min-width: 180px"
          :value="tab.key"
          icon
          active-class="primary"
          :class="`px-8 ${tab.key === selectedTab ? 'white--text' : ''} font-weight-bold`"
          min-width="180"
        >
          {{ $t(tab.key) }}
          <v-icon v-if="tab.valid === false" small color="red lighten-1">mdi-alert</v-icon>
        </v-btn>
      </v-btn-toggle>
      <v-divider />
    </div>

    <!-- tabs content -->
    <v-tabs-items v-if="showTabs" v-model="selectedTab" class="transparent" style="overflow: visible">
      <v-tab-item
        v-for="tab in tabs"
        :key="tab.key"
        eager
        :value="tab.key"
        :transition="false"
        :reverse-transition="false"
        class="py-4"
      >
        <ValidationObserver :ref="tab.key">
          <component :is="tab.cmp" v-on="$listeners" />
        </ValidationObserver>
      </v-tab-item>
    </v-tabs-items>
  </v-form>
</template>
<script>
  import { ValidationObserver } from 'vee-validate'
  import { VRow, VCol, VSelect, VSwitch, VCheckbox, VBtnToggle, VBtn, VTabsItems, VTabItem } from 'vuetify/lib'
  import { CONFIG_TYPE } from './constants'
  import mixin from './mixin'
  import Ipv4 from './ipv4/Ipv4.vue'
  import Ipv6 from './ipv6/Ipv6.vue'
  import Dhcp from './dhcp/Dhcp.vue'
  import Vrrp from './vrrp/Vrrp.vue'

  export default {
    components: {
      ValidationObserver,
      Ipv4,
      Ipv6,
      Vrrp,
      Dhcp,
      VRow,
      VCol,
      VSelect,
      VSwitch,
      VCheckbox,
      VBtnToggle,
      VBtn,
      VTabsItems,
      VTabItem,
    },
    mixins: [mixin],
    inject: ['$intf', '$interfaces', '$status', '$disabled', '$onDelete', '$isSaving', '$interfaceStatuses'],
    data() {
      return {
        selectedTab: null,
        CONFIG_TYPE,
      }
    },
    computed: {
      configTypeTranslated() {
        return this.$t(this.intf.configType.toLowerCase())
      },
      intf: ({ $intf }) => $intf(),
      interfaces: ({ $interfaces }) => $interfaces(),
      interfaceStatuses: ({ $interfaceStatuses }) => $interfaceStatuses(),
      status: ({ $status }) => $status(),
      disabled: ({ $disabled }) => $disabled(),
      isSaving: ({ $isSaving }) => $isSaving(),

      /**
       * used to display a warning message when wan interface gets disabled
       * @returns {String} the interfaces names bound to this wan
       */
      boundInterfaces() {
        if (!this.intf.isWan || this.intf.enabled) {
          return ''
        }
        return this.interfaces
          .reduce((boundInterfaces, intf) => {
            if (intf.boundInterfaceId === this.intf.interfaceId) {
              boundInterfaces.push(intf.name)
            }
            return boundInterfaces
          }, [])
          .join(', ')
      },

      /**
       * returns an array of components to be shown as tabs
       */
      tabs: ({ intf, isAddressed, showDhcp, interfaces }) => {
        const intfIdToNameMap = {}
        const parentBridgedIntfMap = {}
        // let isBridged = false
        interfaces.forEach(i => (intfIdToNameMap[i.interfaceId] = i.name))
        for (const intf of interfaces) {
          if (intf.bridgedInterfaces) {
            for (const bridgeIntf of intf.bridgedInterfaces) {
              parentBridgedIntfMap[bridgeIntf] = intfIdToNameMap[intf.interfaceId]
            }
          }
        }

        return [
          ...(isAddressed
            ? [
                { cmp: 'Ipv4', key: 'ipv4' },
                { cmp: 'Ipv6', key: 'ipv6' },
              ]
            : []),
          // DHCP
          ...(showDhcp ? [{ cmp: 'Dhcp', key: 'dhcp' }] : []),
          // QOS
          // ...(showQos ? [{ cmp: 'Qos', key: 'qos' }] : []),
          // VRRP
          ...(isAddressed ? [{ cmp: 'Vrrp', key: 'vrrp' }] : []),
          ...(intf.type === 'IPSEC'
            ? [
                { cmp: 'IpsecNetwork', key: 'network' },
                { cmp: 'IpsecAuth', key: 'authentication' },
                { cmp: 'IpsecCipherSuites', key: 'cipher_suites' },
              ]
            : []),
        ]
      },
    },
    watch: {
      // update VLAN interface `wan` and `natEgress` options based on selected parent interface
      // 'intf.boundInterfaceId'(id) {
      //   if (!id || !this.intf) {
      //     return
      //   }
      //   if (this.intf.type === 'VLAN') {
      //     const parentIntf = this.interfaces.find(({ interfaceId }) => interfaceId === id)
      //     this.intf.wan = parentIntf.wan
      //   }
      // },
    },
    mounted() {
      this.selectedTab = this.tabs.length ? this.tabs[0].key : undefined
    },

    methods: {
      async validate() {
        const commonValid = await this.$refs.common.validate()
        if (this.showTabs) {
          let invalidTab = null
          // check if tabs fields are valid
          const promises = this.tabs.map(async tab => {
            tab.valid = await this.$refs[tab.key][0].validate()
            if (!tab.valid && !invalidTab) {
              invalidTab = tab.key
            }
            return tab.valid
          })
          // returns an array of resolved promises into `true` (valid) or `false` (invalid)
          const tabsValid = await Promise.all(promises)
          if (invalidTab) this.selectedTab = invalidTab
          return commonValid && !tabsValid.includes(false)
        }
        return commonValid
      },
    },
  }
</script>
