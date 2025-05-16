<template>
  <div>
    <v-radio-group v-model="intf.v6ConfigType" row class="ma-0">
      <v-radio :value="CONFIG_TYPE.AUTO" :label="$t(`Auto (SLAAC/RA)`)" :disabled="!intf.isWan" />
      <v-radio :value="CONFIG_TYPE.STATIC" :label="$t('static')" />
      <v-radio :value="CONFIG_TYPE.DISABLED" :label="$t('disabled')" :disabled="!intf.isWan" />
    </v-radio-group>

    <ipv6-static v-if="intf.v6ConfigType === CONFIG_TYPE.STATIC" />
    <ipv6-auto v-if="intf.v6ConfigType === CONFIG_TYPE.AUTO" />

    <ipv-6-aliases v-if="intf.v6ConfigType !== 'DISABLED'" />
  </div>
</template>
<script>
  import { VRadio, VRadioGroup } from 'vuetify/lib'
  import { CONFIG_TYPE } from '../constants'
  import mixin from '../mixin'
  import Ipv6Static from './Ipv6Static.vue'
  import Ipv6Aliases from './Ipv6Aliases.vue'
  import Ipv6Auto from './Ipv6Auto.vue'

  export default {
    components: {
      VRadio,
      VRadioGroup,
      Ipv6Static,
      Ipv6Aliases,
      Ipv6Auto,
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
      'intf.isWan'(isWan) {
        if (!isWan) {
          this.intf.v6ConfigType = CONFIG_TYPE.STATIC
        }
      },
      'intf.v6Aliases'(v6Aliases) {
        if (!v6Aliases) {
          this.$set(this.intf, 'v6Aliases', {
            javaClass: 'java.util.LinkedList',
            list: [],
          })
        }
      },
    },
  }
</script>
