<template>
  <div>
    <!-- DHCP Serving  -->
    <v-row>
      <v-col class="d-flex" style="gap: 24px">
        <v-checkbox
          v-model="intf.dhcpEnabled"
          :label="$t('enable_dhcp_serving')"
          hide-details
          class="my-0"
          @change="intf.dhcpEnabled ? (intf.dhcpRelayEnabled = false) : null"
        />
        <v-checkbox
          v-model="intf.dhcpRelayEnabled"
          :label="$t('enable_dhcp_relaying')"
          hide-details
          class="my-0"
          @change="intf.dhcpRelayEnabled ? (intf.dhcpEnabled = false) : null"
        />
      </v-col>
    </v-row>

    <template v-if="!intf.dhcpRelayEnabled">
      <v-row>
        <v-col>
          <!-- dhcpRangeStart -->
          <ValidationProvider
            v-slot="{ errors }"
            :rules="{
              required: intf.dhcpEnabled === true,
              ip: true,
              host_in_range: intf.dhcpEnabled ? { ip: intf.v4StaticAddress, cidr: intf.v4StaticPrefix } : false,
            }"
          >
            <u-text-field
              v-model="intf.dhcpRangeStart"
              :label="$t('range_start')"
              :disabled="!intf.dhcpEnabled"
              :error-messages="errors"
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
        <v-col>
          <!-- dhcpRangeEnd -->
          <ValidationProvider
            v-slot="{ errors }"
            :rules="{
              required: intf.dhcpEnabled === true,
              ip: true,
              host_in_range: intf.dhcpEnabled ? { ip: intf.v4StaticAddress, cidr: intf.v4StaticPrefix } : false,
            }"
          >
            <u-text-field
              v-model="intf.dhcpRangeEnd"
              :label="$t('range_end')"
              :disabled="!intf.dhcpEnabled"
              :error-messages="errors"
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
        <v-col>
          <!-- dhcpLeaseDuration (min 120s, max 30 days)-->
          <ValidationProvider v-slot="{ errors }" rules="min_value:120|max_value:2592000">
            <u-text-field
              v-model.number="intf.dhcpLeaseDuration"
              :label="$t('lease_duration')"
              :disabled="!intf.dhcpEnabled"
              :error-messages="errors"
              suffix="sec"
              min="120"
              max="2592000"
              type="number"
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
      </v-row>

      <v-row>
        <v-col>
          <!-- dhcpGatewayOverride -->
          <ValidationProvider v-slot="{ errors }" rules="ip">
            <u-text-field
              v-model="intf.dhcpGatewayOverride"
              :label="$t('gateway_override')"
              :disabled="!intf.dhcpEnabled"
              :error-messages="errors"
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
        <v-col>
          <!-- dhcpPrefixOverride -->
          <ipv-4-prefix-autocomplete
            v-model="intf.dhcpPrefixOverride"
            :disabled="!intf.dhcpEnabled"
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
            <u-text-field v-model="intf.dhcpDNSOverride" :label="$t('dns_override')" :disabled="!intf.dhcpEnabled">
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
      </v-row>

      <dhcp-options v-if="intf.dhcpEnabled" :options.sync="intf.dhcpOptions" />
    </template>

    <!-- DHCP Relaying -->
    <template v-if="intf.dhcpRelayEnabled">
      <v-row>
        <v-col>
          <!-- dhcpRelayAddress -->
          <ValidationProvider
            v-slot="{ errors }"
            :rules="{
              required: intf.dhcpRelayEnabled === true,
              ip: true,
            }"
          >
            <u-text-field
              v-model="intf.dhcpRelayAddress"
              :label="$t('dhcp_relay_address')"
              :disabled="!intf.dhcpRelayEnabled"
              :error-messages="errors"
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
      </v-row>
    </template>
  </div>
</template>
<script>
  import { VRow, VCol, VCheckbox } from 'vuetify/lib'
  import Ipv4PrefixAutocomplete from '../../../../components/Ipv4PrefixAutocomplete'
  import DhcpOptions from './DhcpOptions.vue'

  export default {
    components: { VCheckbox, VRow, VCol, DhcpOptions, Ipv4PrefixAutocomplete },

    inject: ['$intf', '$status'],

    computed: {
      intf: ({ $intf }) => $intf(),
      status: ({ $status }) => $status(),

      dhcpType: {
        get() {
          if (this.intf.dhcpEnabled) return 'dhcpEnabled'
          if (this.intf.dhcpRelayEnabled) return 'dhcpRelayEnabled'
          return null
        },
        set(val) {
          if (val === 'dhcpEnabled') {
            this.intf.dhcpEnabled = true
            this.intf.dhcpRelayEnabled = false
          }
          if (val === 'dhcpRelayEnabled') {
            this.intf.dhcpEnabled = false
            this.intf.dhcpRelayEnabled = true
          }
        },
      },
    },
  }
</script>
