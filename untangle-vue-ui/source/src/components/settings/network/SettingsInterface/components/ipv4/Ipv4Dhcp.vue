<template>
  <div>
    <!-- show current address and renew option only if DHCP -->
    <template v-if="intf.v4ConfigType === CONFIG_TYPE.AUTO_DHCP">
      <div v-if="isAutov4" class="d-flex justify-end">
        <u-btn :small="false" class="px-4 py-2 w-100" style="max-width: 200px; width: 100%" @click="onRenewDhcpLease">
          <v-icon left>mdi-autorenew</v-icon> Renew DHCP Lease
        </u-btn>
      </div>
      <table class="body-2">
        <!-- <tbody>
          <tr>
            <td class="font-weight-bold pr-2">{{ $t('ipv4_address') }}:</td>
            <td>
              <v-progress-circular v-if="isAutov4" indeterminate size="16" />
              <u-btn
                v-if="isAutov4"
                x-small
                rounded
                :small="false"
                :min-width="null"
                class="ml-1"
                :disabled="renewDhcpPending"
                :loading="renewDhcpPending"
                @click="onRenewIp"
              >
                {{ $t('renew_ip') }}
              </u-btn>
            </td>
          </tr>
          <tr v-if="intf.ip4Gateway">
            <td class="font-weight-bold">{{ $t('ipv4_gateway') }}:</td>
            <td>
              <span v-if="!renewDhcpPending">{{ status.ip4Gateway }}</span>
              <span v-else> - </span>
            </td>
          </tr>
          <tr v-if="status.dnsServers">
            <td class="font-weight-bold">{{ $t('dns_servers') }}:</td>
            <td>
              <span v-if="!renewDhcpPending">{{ status.dnsServers.join(', ') }}</span>
              <span v-else> - </span>
            </td>
          </tr>
        </tbody> -->
      </table>
    </template>

    <v-expansion-panels flat>
      <v-expansion-panel class="px-0 mx-0" style="background: transparent">
        <v-expansion-panel-header class="font-weight-bold px-0 pb-0">
          {{ $t('dhcp_overrides_optional') }}
        </v-expansion-panel-header>
        <v-expansion-panel-content class="mx-n6">
          <v-row dense>
            <v-col>
              <!-- v4DhcpAddressOverride -->
              <ValidationProvider v-slot="{ errors }" rules="ip">
                <u-text-field
                  v-model="intf.v4DhcpAddressOverride"
                  :label="$t(`Address Override`)"
                  :error-messages="errors"
                >
                  <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                </u-text-field>
              </ValidationProvider>
            </v-col>
            <v-col>
              <!-- v4DhcpPrefixOverride -->
              <ipv-4-prefix-autocomplete v-model="intf.v4StaticPrefix" :min="1" :required="false" />
            </v-col>
          </v-row>

          <v-row dense>
            <v-col>
              <!-- v4DhcpGatewayOverride -->
              <ValidationProvider v-slot="{ errors }" rules="ip">
                <u-text-field
                  v-model="intf.v4DhcpGatewayOverride"
                  :label="$t(`Gateway Override`)"
                  :error-messages="errors"
                >
                  <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                </u-text-field>
              </ValidationProvider>
            </v-col>
          </v-row>
          <v-row dense>
            <!-- v4DhcpDNS1Override -->
            <v-col cols="6">
              <ValidationProvider v-slot="{ errors }" rules="ip">
                <u-text-field
                  v-model="intf.v4DhcpDNS1Override"
                  :label="$t(`Primary DNS Override`)"
                  :error-messages="errors"
                >
                  <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                </u-text-field>
              </ValidationProvider>
            </v-col>
            <v-col cols="6">
              <!-- v4DhcpDNS2Override -->
              <ValidationProvider v-slot="{ errors }" rules="ip">
                <u-text-field
                  v-model="intf.v4DhcpDNS2Override"
                  :label="$t(`Secondary DNS Override`)"
                  :error-messages="errors"
                >
                  <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                </u-text-field>
              </ValidationProvider>
            </v-col>
          </v-row>
        </v-expansion-panel-content>
      </v-expansion-panel>
    </v-expansion-panels>
  </div>
</template>
<script>
  import { Ipv4PrefixAutocomplete } from 'vuntangle'
  import { CONFIG_TYPE } from '../constants'
  import mixin from '../mixin'

  export default {
    components: {
      Ipv4PrefixAutocomplete,
    },
    mixins: [mixin],
    inject: ['$intf', '$status', '$onRenewDhcp'],
    data() {
      return {
        renewDhcpPending: false,
        CONFIG_TYPE,
      }
    },
    computed: {
      status: ({ $status }) => $status(),
      intf: ({ $intf }) => $intf(),
    },
    methods: {
      onRenewIp() {
        this.renewDhcpPending = true
        this.$onRenewDhcp(this.intf.device, () => (this.renewDhcpPending = false))
      },
    },
  }
</script>
