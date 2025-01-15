<!--
  component used for authentication methods for IPsec service and tunnel definitions
  currently only showing Pre-shared key (shared secret) auth type
-->
<template>
  <div>
    <!-- <p class="font-weight-bold mb-2">{{ $t('select_authentication_method') }}</p> -->

    <!-- select using radios -->
    <!-- <v-radio-group v-model="ipsec.authentication.type" row>
      <v-radio :label="$t('ipsec_psk')" value="shared_secret"></v-radio>
      <v-radio :label="$t('ipsec_pubkey')" value="pubkey"></v-radio>
    </v-radio-group> -->

    <!-- shared secret option: `shared_secret` -->
    <p class="font-weight-bold mb-2">{{ $t('ipsec_psk') }}</p>
    <div v-if="ipsec.authentication.type === 'shared_secret'">
      <ValidationProvider
        v-slot="{ errors }"
        :rules="
          ipsec.authentication.type === 'shared_secret'
            ? { required: true, password: { minChars: 6, letter: false, digit: false, special: false } }
            : ''
        "
      >
        <u-text-field
          v-model="ipsec.authentication.shared_secret"
          :label="$t('shared_secret')"
          :append-icon="reveal ? 'mdi-eye' : 'mdi-eye-off'"
          :type="reveal ? 'text' : 'password'"
          :error-messages="errors"
          @click:append="reveal = !reveal"
        >
          <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
        </u-text-field>
      </ValidationProvider>
    </div>
  </div>
</template>

<script>
  export default {
    inject: ['$intf'],
    data() {
      return {
        reveal: false,
      }
    },
    computed: {
      ipsec: ({ $intf }) => $intf().ipsec,
    },
  }
</script>
