<template>
  <div>
    <!--
        v4ConfigType
        * DHCP, STATIC, PPPOE for wan interfaces
        * STATIC only for non-wan interfaces
      -->
    <v-radio-group v-model="intfCopy.v4ConfigType" row class="ma-0">
      <v-radio value="DHCP" :label="$t('auto_dhcp')" :disabled="!intf.wan" />
      <v-radio value="STATIC" :label="$t('static')" />
      <v-radio value="PPPOE" :label="$t('pppoe')" :disabled="!intf.wan" />
    </v-radio-group>
    <!--
        IPv4 DHCP config
        * - v4DhcpAddressOverride
        * - v4DhcpPrefixOverride
        * - v4DhcpGatewayOverride
        * - v4DhcpDNS1Override
        * - v4DhcpDNS2Override
      -->
    <template v-if="intfCopy.v4ConfigType === 'DHCP'">
      <!-- show current address and renew option only if DHCP -->
      <template v-if="status && status.addressSource.includes('dhcp')">
        <table class="body-2">
          <tbody>
            <tr v-if="status.ip4Addr">
              <td class="font-weight-bold pr-2">{{ $t('ipv4_address') }}:</td>
              <td>
                <span v-if="!renewDhcpPending">{{ status.ip4Addr[0] }}</span>
                <v-progress-circular v-else indeterminate size="16" />
                <u-btn
                  x-small
                  rounded
                  :small="false"
                  :min-width="null"
                  class="ml-1"
                  :disabled="renewDhcpPending"
                  @click="onRenewDhcp"
                >
                  {{ $t('renew_ip') }}
                </u-btn>
              </td>
            </tr>
            <tr v-if="status.ip4Gateway">
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
          </tbody>
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
                    v-model="intfCopy.v4DhcpAddressOverride"
                    :label="$t('address')"
                    :error-messages="errors"
                  >
                    <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                  </u-text-field>
                </ValidationProvider>
              </v-col>
              <v-col>
                <!-- v4DhcpPrefixOverride -->
                <ipv-4-prefix-autocomplete v-model="intfCopy.v4DhcpPrefixOverride" :min="1" :required="false" />
              </v-col>
            </v-row>

            <v-row dense>
              <v-col>
                <!-- v4DhcpGatewayOverride -->
                <ValidationProvider v-slot="{ errors }" rules="ip">
                  <u-text-field
                    v-model="intfCopy.v4DhcpGatewayOverride"
                    :label="$t('gateway')"
                    :error-messages="errors"
                  >
                    <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                  </u-text-field>
                </ValidationProvider>
              </v-col>
            </v-row>
            <v-row dense>
              <v-col cols="6">
                <!-- v4DhcpDNS1Override -->
                <u-text-field v-model="intfCopy.v4DhcpDNS1Override" :label="$t('primary_dns')" />
              </v-col>
              <v-col cols="6">
                <!-- v4DhcpDNS2Override -->
                <u-text-field v-model="intfCopy.v4DhcpDNS2Override" :label="$t('secondary_dns')" />
              </v-col>
            </v-row>
          </v-expansion-panel-content>
        </v-expansion-panel>
      </v-expansion-panels>
    </template>

    <!--
        IPv4 STATIC config
        * - v4StaticAddress
        * - v4StaticPrefix
        * - v4StaticGateway
        * - v4StaticDNS1
        * - v4StaticDNS2
      -->
    <template v-if="intfCopy.v4ConfigType === 'STATIC'">
      <v-row>
        <v-col>
          <!-- v4StaticAddress -->
          <ValidationProvider v-slot="{ errors }" rules="required|ip">
            <u-text-field v-model="intfCopy.v4StaticAddress" :label="$t('address')" :error-messages="errors">
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
        <v-col>
          <!-- v4StaticPrefix -->
          <ValidationProvider v-slot="{ errors }" rules="required">
            <ipv-4-prefix-autocomplete v-model="intfCopy.v4StaticPrefix" :min="1" :errors="errors" />
          </ValidationProvider>
        </v-col>
      </v-row>

      <v-row v-if="intf.wan">
        <v-col>
          <!-- v4StaticGateway (only if interface is WAN) -->
          <ValidationProvider v-slot="{ errors }" rules="required|ip">
            <u-text-field v-model="intfCopy.v4StaticGateway" :label="$t('gateway')" :error-messages="errors">
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
      </v-row>

      <!-- v4StaticDNS1, v4StaticDNS2 (only if interface is WAN) -->
      <v-row v-if="intf.wan">
        <v-col>
          <ValidationProvider v-slot="{ errors }" rules="required|ip">
            <u-text-field v-model="intfCopy.v4StaticDNS1" :label="$t('primary_dns')" :error-messages="errors">
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
        <v-col>
          <ValidationProvider v-slot="{ errors }" rules="ip">
            <u-text-field v-model="intfCopy.v4StaticDNS2" :label="$t('secondary_dns')" :error-messages="errors">
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
      </v-row>
    </template>

    <!--
        IPv4 PPPoE config
        * - v4PPPoEUsername
        * - v4PPPoEPassword
        * - v4PPPoEUsePeerDNS
        * - v4PPPoEOverrideDNS1
        * - v4PPPoEOverrideDNS2
      -->
    <template v-if="intfCopy.v4ConfigType === 'PPPOE'">
      <v-row>
        <v-col>
          <!-- v4PPPoEUsername -->
          <ValidationProvider v-slot="{ errors }" rules="required">
            <u-text-field v-model="intfCopy.v4PPPoEUsername" :label="$t('username')" :error-messages="errors">
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
        <v-col>
          <!-- v4PPPoEPassword -->
          <ValidationProvider v-slot="{ errors }" rules="required|min:6">
            <u-text-field
              v-model="intfCopy.v4PPPoEPassword"
              :label="$t('password')"
              type="password"
              :error-messages="errors"
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
      </v-row>
      <!-- v4PPPoEUsePeerDNS -->
      <v-checkbox v-model="intfCopy.v4PPPoEUsePeerDNS" :label="$t('use_peer_dns')" />
      <v-row>
        <v-col>
          <!-- v4PPPoEOverrideDNS1 -->
          <ValidationProvider v-slot="{ errors }" :rules="{ required: !intfCopy.v4PPPoEUsePeerDNS }">
            <u-text-field
              v-model="intfCopy.v4PPPoEOverrideDNS1"
              :label="$t('primary_dns')"
              :disabled="intfCopy.v4PPPoEUsePeerDNS"
              :error-messages="errors"
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
        <v-col>
          <!-- v4PPPoEOverrideDNS2 -->
          <ValidationProvider v-slot="{ errors }">
            <u-text-field
              v-model="intfCopy.v4PPPoEOverrideDNS2"
              :label="$t('secondary_dns')"
              :disabled="intfCopy.v4PPPoEUsePeerDNS"
              :error-messages="errors"
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
      </v-row>
    </template>

    <v-divider v-if="!isSetup" class="mt-4" />
    <ipv-4-aliases
      v-if="!isSetup"
      :aliases.sync="intfCopy.v4Aliases"
      :interface-id="intf.interfaceId"
      :v4-static-address="intfCopy.v4StaticAddress"
    />
  </div>
</template>
<script>
  import cloneDeep from 'lodash/cloneDeep'
  import merge from 'lodash/merge'
  import Ipv4Aliases from './Ipv4Aliases.vue'
  import api from '@/plugins/api'

  export default {
    components: { Ipv4Aliases },
    props: {
      intf: { type: Object, default: () => {} },
      status: { type: Object, default: () => {} },
      /**
       * flag telling if the component is used in setup wizard
       * this is used to enable or disable some features depending on component usage (in setup or not)
       */
      isSetup: { type: Boolean, default: false },
    },
    data() {
      return {
        intfCopy: {
          v4ConfigType: this.intf.v4ConfigType || 'STATIC',
          v4DhcpAddressOverride: this.intf.v4DhcpAddressOverride || '',
          v4DhcpPrefixOverride: this.intf.v4DhcpPrefixOverride || null,
          v4DhcpGatewayOverride: this.intf.v4DhcpGatewayOverride || '',
          v4DhcpDNS1Override: this.intf.v4DhcpDNS1Override || '',
          v4DhcpDNS2Override: this.intf.v4DhcpDNS2Override || '',
          v4StaticAddress: this.intf.v4StaticAddress || '',
          v4StaticPrefix: this.intf.v4StaticPrefix || 24,
          v4StaticGateway: this.intf.v4StaticGateway || '',
          v4StaticDNS1: this.intf.v4StaticDNS1 || '',
          v4StaticDNS2: this.intf.v4StaticDNS2 || '',
          v4PPPoEUsername: this.intf.v4PPPoEUsername || '',
          v4PPPoEPassword: this.intf.v4PPPoEPassword || '',
          v4PPPoEUsePeerDNS: this.intf.v4PPPoEUsePeerDNS || false,
          v4PPPoEOverrideDNS1: this.intf.v4PPPoEOverrideDNS1 || '',
          v4PPPoEOverrideDNS2: this.intf.v4PPPoEOverrideDNS2 || '',
          v4Aliases: this.intf.v4Aliases?.length ? cloneDeep(this.intf.v4Aliases) : [],
        },
        renewDhcpPending: false,
      }
    },
    watch: {
      intfCopy: {
        deep: true,
        // copy the intf prop and override with intfCopy, send back to the parents .sync
        handler(newIntfCopy) {
          this.$emit('update:intf', merge({}, this.intf, { v4Aliases: null }, newIntfCopy))
        },
      },
      // when switching wan to true/false set `v4ConfigType` to 'STATIC'
      'intf.wan'(isWan) {
        if (!isWan && this.intfCopy.v4ConfigType !== 'STATIC') {
          this.intfCopy.v4ConfigType = 'STATIC'
        }
      },
    },
    methods: {
      async onRenewDhcp() {
        this.renewDhcpPending = true
        await api.post(`/api/renewdhcp/${this.intf.device}`)
        // invoke getting status in parent component
        this.$emit('get-status')
        this.renewDhcpPending = false
      },
    },
  }
</script>
