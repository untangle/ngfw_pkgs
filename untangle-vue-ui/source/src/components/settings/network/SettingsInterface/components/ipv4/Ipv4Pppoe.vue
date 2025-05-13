<template>
  <div>
    <v-row>
      <v-col v-if="isPPPOEv4">
        <!-- v4PPPoEUsername -->
        <ValidationProvider v-slot="{ errors }" rules="required">
          <u-text-field v-model="intf.v4PPPoEUsername" :label="$t('username')" :error-messages="errors">
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
      <v-col>
        <!-- v4PPPoEPassword -->
        <ValidationProvider v-slot="{ errors }" rules="required">
          <u-text-field v-model="intf.v4PPPoEPassword" :label="$t('password')" type="password" :error-messages="errors">
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
    </v-row>
    <!-- v4PPPoEUsePeerDNS -->
    <v-checkbox v-model="intf.v4PPPoEUsePeerDns" :label="$t('use_peer_dns')" />
    <v-row>
      <v-col>
        <!-- v4PPPoEDns1 -->
        <ValidationProvider v-slot="{ errors }" rules="ip">
          <u-text-field
            v-model="intf.v4PPPoEDns1"
            :label="$t('primary_dns')"
            :disabled="intf.v4PPPoEUsePeerDns"
            :error-messages="errors"
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
      <v-col>
        <!-- v4PPPoEDns2 -->
        <ValidationProvider v-slot="{ errors }" rules="ip">
          <u-text-field
            v-model="intf.v4PPPoEDns2"
            :label="$t('secondary_dns')"
            :disabled="intf.v4PPPoEUsePeerDns"
            :error-messages="errors"
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
    </v-row>
  </div>
</template>
<script>
  import mixin from '../mixin'
  import util from '../../../../../../util/setupUtil'
  // const passwordFill = '******'

  export default {
    mixins: [mixin],
    inject: ['$intf'],
    computed: {
      intf: ({ $intf }) => $intf(),
    },
    mounted() {
      if (!this.intf.v4PPPoEPassword) {
        this.intf.v4PPPoEPassword = util.getDecryptedPassword(this.intf.v4PPPoEPasswordEncrypted)
      }
    },
  }
</script>
