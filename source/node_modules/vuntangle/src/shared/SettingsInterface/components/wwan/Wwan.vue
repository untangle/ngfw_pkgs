<template>
  <div>
    <!-- show enabled/disabled option if component used in setup wizard -->
    <div class="d-flex">
      <v-switch v-if="isSetup" v-model="intf.enabled" :label="$t('interface_enabled')" class="mt-0" />
    </div>
    <v-row>
      <v-col>
        <u-select v-model="intf.simNetwork" :items="simNetworksOptions" :label="$t('network')" @change="setApn" />
      </v-col>
      <v-col v-if="intf.simNetwork !== 'Verizon'">
        <ValidationProvider v-slot="{ errors }" :rules="{ required: intf.simNetwork === 'AT&T' }">
          <u-text-field
            v-if="intf.simNetwork === 'T-Mobile' || intf.simNetwork === 'AT&T'"
            v-model="intf.simApn"
            :label="apn"
            :disabled="intf.simNetwork === 'T-Mobile'"
            :error-messages="errors"
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
    </v-row>
    <u-section v-if="simDetails" :title="$t('sim_details')" class="mt-8" style="margin-bottom: 0 !important">
      <ul>
        <li>IMEI: {{ simDetails.imei || $t('n_a') }}</li>
        <li>IMSI: {{ simDetails.imsi || $t('n_a') }}</li>
        <li>ICCID: {{ simDetails.iccid || $t('n_a') }}</li>
      </ul>
    </u-section>
  </div>
</template>
<script>
  // import http from '@/plugins/http'

  export default {
    inject: ['$intf', '$status'],
    props: {
      /**
       * flag telling if the component is used in setup wizard
       */
      isSetup: { type: Boolean, default: false },
    },
    data() {
      return {
        simApns: {
          'T-Mobile': 'fast.t-mobile.com',
          'Verizon': null,
          'AT&T': 'm2m.com.attz',
        },
        simDetails: null,
      }
    },
    computed: {
      intf: ({ $intf }) => $intf(),
      status: ({ $status }) => $status(),

      simNetworksOptions() {
        return [
          { text: this.$t('t_mobile'), value: 'T-Mobile' },
          { text: this.$t('verizon'), value: 'Verizon' },
          { text: this.$t('at_t'), value: 'AT&T' },
        ]
      },
    },
    async created() {
      await this.$emit('get-status-wwan', this.intf.device, response => {
        // returns an array of objects like { 'frequency': '2.412 GHz', 'channel': 1 }
        this.simDetails = response || null
      })
    },
    methods: {
      setApn(network) {
        this.intf.simApn = this.simApns[network]
      },
    },
  }
</script>
