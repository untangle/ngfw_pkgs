<template>
  <div>
    <template v-if="intf">
      <table class="body-2">
        <tbody>
          <tr v-if="intf.ip6Addr">
            <td class="font-weight-bold">{{ $t('ipv6_address') }}:</td>
            <td>
              <span>{{ intf.ip6Addr.join(', ') }}</span>
            </td>
          </tr>
          <tr v-if="intf.ip6Gateway">
            <td class="font-weight-bold">{{ $t('ipv6_gateway') }}:</td>
            <td>
              <span>{{ intf.ip6Gateway }}</span>
            </td>
          </tr>
          <tr v-if="intf.dnsServers">
            <td class="font-weight-bold">{{ $t('dns_servers') }}:</td>
            <td>
              <span>{{ intf.dnsServers.join(', ') }}</span>
            </td>
          </tr>
        </tbody>
      </table>
    </template>
    <v-divider class="my-4" />

    <p class="font-weight-bold">{{ $t('dhcp_overrides_optional') }}</p>
    <v-row>
      <v-col>
        <!-- v6DhcpDNS1Override -->
        <ValidationProvider v-slot="{ errors }" rules="ip_v6">
          <u-text-field
            v-model="intf.v6DhcpDNS1Override"
            :label="$t('primary_dns')"
            class="mr-2"
            :error-messages="errors"
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
      <v-col>
        <!-- v6DhcpDNS2Override -->
        <ValidationProvider v-slot="{ errors }" rules="ip_v6">
          <u-text-field
            v-model="intf.v6DhcpDNS2Override"
            :label="$t('secondary_dns')"
            class="ml-2"
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
  export default {
    inject: ['$intf', '$status'],
    computed: {
      intf: ({ $intf }) => $intf(),
      status: ({ $status }) => $status(),
    },
  }
</script>
