<template>
  <div>
    <v-radio-group v-model="intf.v4ConfigType" row class="ma-0">
      <v-radio :value="CONFIG_TYPE.DHCP" :label="$t('auto_dhcp')" :disabled="!intf.wan && !intf.management" />
      <v-radio :value="CONFIG_TYPE.STATIC" :label="$t('static')" />
      <v-radio
        v-if="features.hasPppoe && !intf.management"
        :value="CONFIG_TYPE.PPPOE"
        :label="$t('pppoe')"
        :disabled="!intf.wan"
      />
      <v-radio :value="CONFIG_TYPE.DISABLED" :label="$t('disabled')" />
    </v-radio-group>

    <ipv4-dhcp v-if="intf.v4ConfigType === CONFIG_TYPE.DHCP" />
    <ipv4-static v-if="intf.v4ConfigType === CONFIG_TYPE.STATIC" />
    <ipv4-pppoe v-if="intf.v4ConfigType === CONFIG_TYPE.PPPOE" />

    <ipv-4-aliases v-if="intf.v4ConfigType !== CONFIG_TYPE.DISABLED" />
  </div>
</template>
<script>
  import { CONFIG_TYPE } from '../constants'
  import Ipv4Dhcp from './Ipv4Dhcp.vue'
  import Ipv4Static from './Ipv4Static.vue'
  import Ipv4Pppoe from './Ipv4Pppoe.vue'
  import Ipv4Aliases from './Ipv4Aliases.vue'

  export default {
    components: {
      Ipv4Dhcp,
      Ipv4Static,
      Ipv4Pppoe,
      Ipv4Aliases,
    },
    inject: ['$intf', '$features'],
    data() {
      return {
        CONFIG_TYPE,
      }
    },
    computed: {
      intf: ({ $intf }) => $intf(),
      features: ({ $features }) => $features(),
    },

    watch: {
      // when switching wan to true/false set `v4ConfigType` to 'STATIC'
      'intf.wan'(wan) {
        if (!wan && this.intf.v4ConfigType !== CONFIG_TYPE.STATIC) {
          this.intf.v4ConfigType = CONFIG_TYPE.STATIC
        }
      },
    },
  }
</script>
