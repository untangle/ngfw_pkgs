<template>
  <div>
    <v-row>
      <v-col cols="8">
        <!-- v6StaticAddress -->
        <ValidationProvider v-slot="{ errors }" rules="required|ip_v6">
          <u-text-field v-model="intf.v6StaticAddress" :label="$t('address')" :error-messages="errors">
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
      <v-col cols="4">
        <!-- v6StaticPrefix -->
        <ValidationProvider v-slot="{ errors }" rules="required|min_value:1|max_value:128">
          <u-text-field
            v-model.number="intf.v6StaticPrefix"
            :label="$t('prefix_length')"
            placeholder="1-128"
            type="number"
            :error-messages="errors"
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
    </v-row>
    <v-row v-if="intf.wan">
      <v-col>
        <!-- v6StaticGateway -->
        <ValidationProvider v-slot="{ errors }" rules="required">
          <u-text-field v-model="intf.v6StaticGateway" :label="$t('gateway')" :error-messages="errors">
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
    </v-row>

    <!-- v6StaticDNS1, v6StaticDNS2 (only if interface is WAN) -->
    <v-row v-if="intf.wan">
      <v-col>
        <ValidationProvider v-slot="{ errors }" rules="ip_v6">
          <u-text-field v-model="intf.v6StaticDNS1" :label="$t('primary_dns')" :error-messages="errors">
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
      <v-col>
        <ValidationProvider v-slot="{ errors }" rules="ip_v6">
          <u-text-field v-model="intf.v6StaticDNS2" :label="$t('secondary_dns')" :error-messages="errors">
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
    </v-row>
  </div>
</template>
<script>
  export default {
    inject: ['$intf', '$status'],
    computed: {
      intf: ({ $intf }) => $intf(),
      status: ({ $status }) => $status(),
    },
  }
</script>
