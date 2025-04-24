<template>
  <div>
    <v-col class="d-flex" style="gap: 24px">
      <v-radio-group v-model="intf.dhcpType" row class="ma-0">
        <v-radio class="my-0" :value="CONFIG_TYPE.SERVER" :label="$t(`Server`)" />
        <v-radio class="my-0" :value="CONFIG_TYPE.RELAY" :label="$t('Relay')" />
        <v-radio class="my-0" :value="CONFIG_TYPE.DISABLED" :label="$t('disabled')" />
      </v-radio-group>
    </v-col>

    <template v-if="intf.dhcpType === CONFIG_TYPE.DISABLED">
      <p>DHCP Server and Relay disabled</p>
    </template>

    <template v-if="intf.dhcpType === CONFIG_TYPE.SERVER">
      <v-row>
        <v-col>
          <!-- dhcpRangeStart -->
          <ValidationProvider
            v-slot="{ errors }"
            :rules="{
              required: true,
              ip: true,
              host_in_range: intf.dhcpRangeStart ? { ip: intf.v4StaticAddress, cidr: intf.v4StaticPrefix } : false,
            }"
          >
            <u-text-field v-model="intf.dhcpRangeStart" :label="$t('range_start')" :error-messages="errors">
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
        <v-col>
          <!-- dhcpRangeEnd -->
          <ValidationProvider
            v-slot="{ errors }"
            :rules="{
              required: true,
              ip: true,
              host_in_range: intf.dhcpRangeEnd ? { ip: intf.v4StaticAddress, cidr: intf.v4StaticPrefix } : false,
            }"
          >
            <u-text-field v-model="intf.dhcpRangeEnd" :label="$t('range_end')" :error-messages="errors">
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
        <v-col>
          <!-- dhcpLeaseDuration (min 120s, max 30 days)-->
          <ValidationProvider v-slot="{ errors }" rules="required|min_value:120">
            <u-text-field
              v-model.number="intf.dhcpLeaseDuration"
              :label="$t('lease_duration')"
              :error-messages="errors"
              suffix="sec"
              min="120"
              type="number"
            >
              <span class="pa-2">
                <span class="text-grey ma-2">seconds :</span>
              </span>
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
      </v-row>

      <v-row>
        <v-col>
          <!-- dhcpGatewayOverride -->
          <ValidationProvider v-slot="{ errors }" rules="ip">
            <u-text-field v-model="intf.dhcpGatewayOverride" :label="$t('gateway_override')" :error-messages="errors">
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
        <v-col>
          <!-- dhcpPrefixOverride -->
          <ipv-4-prefix-autocomplete
            v-model="intf.dhcpPrefixOverride"
            :label-tkey="$t('netmask_override')"
            :min="1"
            :required="false"
            :default-value="''"
          />
        </v-col>
      </v-row>

      <v-row>
        <v-col>
          <!-- dhcpDNSOverride -->
          <ValidationProvider v-slot="{ errors }" rules="ip">
            <u-text-field v-model="intf.dhcpDNSOverride" :label="$t('dns_override')">
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
      </v-row>
      <!-- <dhcp-aliases v-if="intf.dhcpType === CONFIG_TYPE.SERVER" /> -->
      <dhcp-options :options.sync="intf.dhcpOptions" />
    </template>

    <!-- DHCP Relaying -->
    <template v-if="intf.dhcpType === CONFIG_TYPE.RELAY">
      <v-row>
        <v-col>
          <!-- dhcpRelayAddress -->
          <ValidationProvider v-slot="{ errors }" :rules="{ required: true }">
            <u-text-field v-model="intf.dhcpRelayAddress" :label="$t('Relay Host Address')" :error-messages="errors">
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
      </v-row>
    </template>
  </div>
</template>
<script>
  import { VRow, VCol } from 'vuetify/lib'
  import { Ipv4PrefixAutocomplete } from 'vuntangle'
  import { CONFIG_TYPE } from '../constants'
  import DhcpOptions from './DhcpOptions.vue'
  // import Util from '../../../Util.js'

  export default {
    components: { VRow, VCol, DhcpOptions, Ipv4PrefixAutocomplete },

    inject: ['$intf', '$status'],
    data() {
      return {
        CONFIG_TYPE,
      }
    },
    computed: {
      intf: ({ $intf }) => $intf(),
      status: ({ $status }) => $status(),
    },
  }
</script>
