<template>
  <div>
    <v-radio-group v-model="intf.v6ConfigType" row class="ma-0">
      <v-radio :value="CONFIG_TYPE.AUTO" :label="$t(`Auto (SLAAC/RA)`)" :disabled="!intf.isWan" />
      <v-radio :value="CONFIG_TYPE.STATIC" :label="$t('static')" />
      <!-- <v-radio v-if="intf.wan" :value="CONFIG_TYPE.SLAAC" :label="$t('slaac')" /> -->
      <v-radio :value="CONFIG_TYPE.DISABLED" :label="$t('disabled')" :disabled="!intf.isWan" />
    </v-radio-group>

    <!-- <ipv6-dhcp v-if="intf.v6ConfigType === CONFIG_TYPE.DHCP" /> -->
    <ipv6-assign v-if="intf.v6ConfigType === CONFIG_TYPE.DHCP" />

    <ipv6-static v-if="intf.v6ConfigType === CONFIG_TYPE.STATIC" />
    <ipv6-assign v-if="intf.v6ConfigType === CONFIG_TYPE.ASSIGN" />

    <div class="d-flex" style="gap: 24px">
      <v-checkbox
        v-if="intf.v6ConfigType !== CONFIG_TYPE.DISABLED"
        v-model="intf.routerAdvertisements"
        :label="$t('send_router_advertisements')"
        hide-details
      />
      <v-checkbox
        v-if="intf.wan && intf.v6ConfigType !== CONFIG_TYPE.DISABLED"
        v-model="intf.v6RelayEnabled"
        :label="$t('dhcp_v6_relay')"
        hide-details
      />
    </div>
    <ipv-6-aliases v-if="intf.v6ConfigType !== 'DISABLED'" />
  </div>
</template>
<script>
  import { VCheckbox, VRadio, VRadioGroup } from 'vuetify/lib'
  import { CONFIG_TYPE } from '../constants'
  // import Ipv6Dhcp from './Ipv6Dhcp.vue'
  import Ipv6Static from './Ipv6Static.vue'
  import Ipv6Assign from './Ipv6Assign.vue'
  import Ipv6Aliases from './Ipv6Aliases.vue'

  export default {
    components: {
      VCheckbox,
      VRadio,
      VRadioGroup,
      // Ipv6Dhcp,
      Ipv6Static,
      Ipv6Assign,
      Ipv6Aliases,
    },

    inject: ['$intf'],

    data() {
      return {
        CONFIG_TYPE,
      }
    },

    computed: {
      intf: ({ $intf }) => $intf(),
    },

    watch: {
      /**
       * when switching wan to true/false set `v6ConfigType` to 'DISABLED'
       * due to dynamic nature of `v6ConfigType` based on wan
       */
      // 'intf.wan'() {
      //   this.intf.v6ConfigType = CONFIG_TYPE.DISABLED
      // },
    },
  }
</script>
