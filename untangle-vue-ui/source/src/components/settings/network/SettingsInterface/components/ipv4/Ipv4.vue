<template>
  <div>
    <v-radio-group v-model="intf.v4ConfigType" row class="ma-0" @change="onChangeConfigType">
      <v-radio :value="CONFIG_TYPE.AUTO_DHCP" :label="$t('auto_dhcp')" :disabled="!intf.isWan" />
      <v-radio :value="CONFIG_TYPE.STATIC" :label="$t('static')" />
      <v-radio :value="CONFIG_TYPE.PPPOE" :label="$t('pppoe')" :disabled="!intf.isWan" />
    </v-radio-group>

    <ipv4-dhcp v-if="intf.v4ConfigType === CONFIG_TYPE.AUTO_DHCP" />
    <ipv4-static v-if="intf.v4ConfigType === CONFIG_TYPE.STATIC" />
    <ipv4-pppoe v-if="intf.v4ConfigType === CONFIG_TYPE.PPPOE" />
    <ipv-4-aliases v-if="intf.v4ConfigType !== CONFIG_TYPE.DISABLED" />
  </div>
</template>
<script>
  import { CONFIG_TYPE } from '../constants'
  import CommonUtil from '../../../../../../util/util'
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
    inject: ['$intf'],
    data() {
      return {
        CONFIG_TYPE,
        previousConfigType: null,
      }
    },
    computed: {
      intf: ({ $intf }) => $intf(),
    },
    watch: {
      // when switching wan to true/false set `v4ConfigType` to 'STATIC'
      'intf.isWan'(isWan) {
        if (!isWan) {
          this.intf.v4ConfigType = CONFIG_TYPE.STATIC
        }
      },
      'intf.v4Aliases'(v4Aliases) {
        if (!v4Aliases) {
          this.$set(this.intf, 'v4Aliases', {
            javaClass: 'java.util.LinkedList',
            list: [],
          })
        }
      },
    },
    mounted() {
      this.previousConfigType = this.intf.v4ConfigType
    },
    methods: {
      onChangeConfigType(newValue) {
        const oldValue = this.previousConfigType
        this.previousConfigType = newValue

        if (oldValue !== newValue) {
          if (newValue !== this.CONFIG_TYPE.PPPOE) {
            this.intf.v4PPPoEPassword = null
          } else if (this.intf.v4PPPoEPasswordEncrypted && !this.intf.v4PPPoEPassword) {
            this.intf.v4PPPoEPassword = CommonUtil.getDecryptedPassword(this.intf.v4PPPoEPasswordEncrypted)
          }
        }
      },
    },
  }
</script>
