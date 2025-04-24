<template>
  <div>
    <v-row>
      <v-col>
        <!-- v4StaticAddress -->
        <ValidationProvider v-slot="{ errors }" :rules="{ required: true, ip: true }">
          <u-text-field v-model="intf.v4StaticAddress" :label="$t('address')" :error-messages="errors">
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
      <v-col>
        <!-- v4StaticPrefix -->
        <ValidationProvider v-slot="{ errors }" :rules="{ required: true }">
          <ipv-4-prefix-autocomplete v-model="intf.v4StaticPrefix" :min="1" :errors="errors" />
        </ValidationProvider>
      </v-col>
    </v-row>
    <v-row v-if="intf.isWan">
      <v-col>
        <!-- v4StaticGateway (only if interface is WAN) -->
        <ValidationProvider v-slot="{ errors }" :rules="{ required: true, ip: true }">
          <u-text-field v-model="intf.v4StaticGateway" :label="$t('gateway')" :error-messages="errors">
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
    </v-row>

    <!-- v4StaticDNS1, v4StaticDNS2 (only if interface is WAN) -->
    <v-row v-if="intf.isWan">
      <v-col>
        <ValidationProvider v-slot="{ errors }" :rules="{ required: true, ip: true }">
          <u-text-field v-model="intf.v4StaticDNS1" :label="$t('primary_dns')" :error-messages="errors">
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
      <v-col>
        <ValidationProvider v-slot="{ errors }" :rules="{ required: true, ip: true }">
          <u-text-field v-model="intf.v4StaticDNS2" :label="$t('secondary_dns')" :error-messages="errors">
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
    </v-row>
  </div>
</template>
<script>
  // import { rules } from 'node_modules/eslint-plugin-sort-keys-fix/lib/index'
  import { Ipv4PrefixAutocomplete } from 'vuntangle'

  export default {
    components: {
      Ipv4PrefixAutocomplete,
    },
    inject: ['$intf'],
    computed: {
      intf: ({ $intf }) => $intf(),
    },
  }
</script>
