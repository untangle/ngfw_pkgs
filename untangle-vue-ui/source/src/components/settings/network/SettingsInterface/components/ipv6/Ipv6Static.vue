<template>
  <div v-if="isStaticv6">
    <v-row>
      <v-col cols="8">
        <!-- v6StaticAddress -->
        <ValidationProvider v-slot="{ errors }" rules="ip_v6">
          <u-text-field v-model="intf.v6StaticAddress" :label="$t('address')" :error-messages="errors">
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
      <v-col cols="4">
        <!-- v6StaticPrefixLength -->
        <ValidationProvider v-slot="{ errors }" rules="required|min_value:1|max_value:128">
          <u-text-field
            v-model.number="intf.v6StaticPrefixLength"
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
    <v-row v-if="intf.isWan">
      <v-col>
        <ValidationProvider v-slot="{ errors }">
          <u-text-field v-model="intf.v6StaticGateway" :label="$t('gateway')" :error-messages="errors">
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
    </v-row>

    <v-row v-if="intf.isWan">
      <v-col>
        <ValidationProvider v-slot="{ errors }" rules="ip_v6">
          <u-text-field v-model="intf.v6StaticDns1" :label="$t('primary_dns')" :error-messages="errors">
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
      <v-col>
        <ValidationProvider v-slot="{ errors }" rules="ip_v6">
          <u-text-field v-model="intf.v6StaticDns2" :label="$t('secondary_dns')" :error-messages="errors">
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
    </v-row>
  </div>
</template>
<script>
  import mixin from '../mixin'

  export default {
    mixins: [mixin],
    inject: ['$intf', '$status'],
    computed: {
      intf: ({ $intf }) => $intf(),
      status: ({ $status }) => $status(),
    },
    mounted() {
      // Set default value if not already set
      if (!this.intf.v6StaticPrefixLength) {
        this.$set(this.intf, 'v6StaticPrefixLength', 64)
      }
    },
  }
</script>
