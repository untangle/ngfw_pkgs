<template>
  <div>
    <v-row>
      <v-col>
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
          <u-text-field
            v-model="pppoePassword"
            :label="$t('password')"
            type="password"
            :error-messages="errors"
            @focus="onFocus"
            @blur="onBlur"
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
    </v-row>
    <!-- v4PPPoEUsePeerDNS -->
    <v-checkbox v-model="intf.v4PPPoEUsePeerDNS" :label="$t('use_peer_dns')" />
    <v-row>
      <v-col>
        <!-- v4PPPoEOverrideDNS1 -->
        <ValidationProvider
          v-slot="{ errors }"
          :rules="{ required: !intf.v4PPPoEUsePeerDNS, ip: !intf.v4PPPoEUsePeerDNS }"
        >
          <u-text-field
            v-model="intf.v4PPPoEOverrideDNS1"
            :label="$t('primary_dns')"
            :disabled="intf.v4PPPoEUsePeerDNS"
            :error-messages="errors"
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
      <v-col>
        <!-- v4PPPoEOverrideDNS2 -->
        <ValidationProvider v-slot="{ errors }" rules="ip">
          <u-text-field
            v-model="intf.v4PPPoEOverrideDNS2"
            :label="$t('secondary_dns')"
            :disabled="intf.v4PPPoEUsePeerDNS"
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
  const passwordFill = '******'

  export default {
    inject: ['$intf'],

    computed: {
      intf: ({ $intf }) => $intf(),
      pppoePassword: {
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

    methods: {
      /**
       * Empty the field when settings a new password
       */
      onFocus() {
        if (this.pppoePassword === passwordFill) this.pppoePassword = ''
      },

      /**
       * Fill in the dummy password fill if password field is empty
       * and remove it from interface settings
       */
      onBlur() {
        if (this.pppoePassword === '') {
          this.pppoePassword = passwordFill
          this.$delete(this.intf, 'v4PPPoEPassword')
        }
      },
    },
  }
</script>
