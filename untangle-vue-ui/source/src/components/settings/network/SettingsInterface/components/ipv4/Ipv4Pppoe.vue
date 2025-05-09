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
        <ValidationProvider v-slot="{ errors }" rules="required|min:6">
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

  const passwordFill = '******'

  export default {
    mixins: [mixin],
    inject: ['$intf'],
    computed: {
      intf: ({ $intf }) => $intf(),
      v4PPPoEPassword: {
        /**
         * If we do have the `v4PPPoEPasswordEncrypted` means a password was already set (edit mode)
         * and if password field is not being touched it will be just filled with 6 dots
         */
        get: ({ intf }) =>
          intf.v4PPPoEPasswordEncrypted && !('v4PPPoEPassword' in intf) ? passwordFill : intf.v4PPPoEPassword,
        set(value) {
          // on password field input, just set/update the `v4PPPoEPassword` plain password prop on interface settings
          this.$set(this.intf, 'v4PPPoEPassword', value)
        },
      },
    },
  }
</script>
