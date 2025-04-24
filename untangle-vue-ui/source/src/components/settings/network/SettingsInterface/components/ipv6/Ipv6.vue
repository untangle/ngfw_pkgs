<template>
  <div>
    <v-radio-group v-model="intf.v6ConfigType" row class="ma-0">
      <v-radio :value="CONFIG_TYPE.AUTO" :label="$t(`Auto (SLAAC/RA)`)" :disabled="!intf.isWan" />
      <v-radio :value="CONFIG_TYPE.STATIC" :label="$t('static')" />
      <v-radio :value="CONFIG_TYPE.DISABLED" :label="$t('disabled')" :disabled="!intf.isWan" />
    </v-radio-group>

    <!-- <ipv6-assign v-if="intf.v6ConfigType === CONFIG_TYPE.DHCP" /> -->

    <ipv6-static v-if="intf.v6ConfigType === CONFIG_TYPE.STATIC" />
    <ipv6-auto v-if="intf.v6ConfigType === CONFIG_TYPE.AUTO" />

    <!-- Auto (SLAAC/RA) -->
    <!-- <div v-if="!isDisabledv6 && !isAutov6 && !intf.isWan" class="d-flex" style="gap: 24px">
      <v-checkbox v-model="intf.raEnabled" :label="$t('send_router_advertisements')" hide-details />
      <span v-if="showRouterWarning" class="mx-2">
        <v-avatar size="12" class="bg-orange-darken-2 mx-2"></v-avatar>
        <label>{{ 'SLAAC only works with /64 subnets.' }}</label>
      </span>
    </div> -->
    <ipv-6-aliases v-if="intf.v6ConfigType !== 'DISABLED'" />
  </div>
</template>
<script>
  import { VRadio, VRadioGroup } from 'vuetify/lib'
  import { CONFIG_TYPE } from '../constants'
  import mixin from '../mixin'
  import Ipv6Static from './Ipv6Static.vue'
  // import Ipv6Auto from './Ipv6Auto.vue'
  import Ipv6Aliases from './Ipv6Aliases.vue'

  export default {
    components: {
      VRadio,
      VRadioGroup,
      Ipv6Static,
      Ipv6Aliases,
    },
    mixins: [mixin],

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
       * due to dynamic nature of `v6ConfigType` based on isWan
       */
      // 'intf.isWan'() {
      //   this.intf.v6ConfigType = CONFIG_TYPE.DISABLED
      // },
    },
  }
</script>
