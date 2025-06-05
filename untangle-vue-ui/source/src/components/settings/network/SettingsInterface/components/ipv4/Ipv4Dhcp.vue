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
            <v-col cols="6">
              <!-- v4AutoAddressOverride -->
              <span class="text-grey ma-2">Address Override :</span>
              <ValidationProvider v-slot="{ errors }" rules="ip">
                <u-text-field v-model="intf.v4AutoAddressOverride" :label="status.v4Address" :error-messages="errors">
                  <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                </u-text-field>
              </ValidationProvider>
            </v-col>
            <v-col v-show="status.v4Address" cols="6" class="pt-8">
              <span class="pa-2">
                <span class="text-grey ma-2">Current :</span>
                <strong>{{ status.v4Address }}</strong>
              </span>
            </v-col>
          </v-row>
          <v-row dense>
            <v-col cols="6">
              <!-- v4AutoPrefixOverride -->
              <span class="text-grey ma-2">Netmask Override :</span>
              <ipv-4-prefix-autocomplete
                v-model="intf.v4AutoPrefixOverride"
                :label="`${status.v4PrefixLength} - ${status.v4Netmask}`"
                :min="1"
                :required="false"
              />
            </v-col>
            <v-col v-show="status.v4Netmask" cols="6" class="pt-8">
              <span class="pa-2">
                <span class="text-grey ma-2">Current :</span>
                <strong> / {{ status.v4PrefixLength }} - {{ status.v4Netmask }}</strong>
              </span>
            </v-col>
          </v-row>

          <v-row dense>
            <v-col cols="6">
              <!-- v4AutoGatewayOverride -->
              <span class="text-grey ma-2">Gateway Override :</span>
              <ValidationProvider v-slot="{ errors }" rules="ip">
                <u-text-field v-model="intf.v4AutoGatewayOverride" :label="status.v4Gateway" :error-messages="errors">
                  <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                </u-text-field>
              </ValidationProvider>
            </v-col>
            <v-col v-show="status.v4Gateway" cols="6" class="pt-8">
              <span class="pa-2">
                <span class="text-grey ma-2">Current :</span>
                <strong>{{ status.v4Gateway }}</strong>
              </span>
            </v-col>
          </v-row>
          <v-row dense>
            <!-- v4AutoDns1Override -->
            <v-col cols="6">
              <span class="text-grey ma-2">Primary DNS Override :</span>
              <ValidationProvider v-slot="{ errors }" rules="ip">
                <u-text-field v-model="intf.v4AutoDns1Override" :label="status.v4Dns1" :error-messages="errors">
                  <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                </u-text-field>
              </ValidationProvider>
            </v-col>
            <v-col v-show="status.v4Dns1" cols="6" class="pt-8">
              <span class="pa-2">
                <span class="text-grey ma-2">Current :</span>
                <strong>{{ status.v4Dns1 }}</strong>
              </span>
            </v-col>
          </v-row>
          <v-row dense>
            <v-col cols="6">
              <span class="text-grey ma-2">Secondary DNS Override :</span>
              <!-- v4AutoDns2Override -->
              <ValidationProvider v-slot="{ errors }" rules="ip">
                <u-text-field v-model="intf.v4AutoDns2Override" :label="status.v4Dns2" :error-messages="errors">
                  <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                </u-text-field>
              </ValidationProvider>
            </v-col>
            <v-col v-show="status.v4Dns2" cols="6" class="pt-8">
              <span class="pa-2">
                <span class="text-grey ma-2">Current :</span>
                <strong>{{ status.v4Dns2 }}</strong>
              </span>
            </v-col>
          </v-row>
        </v-expansion-panel-content>
      </v-expansion-panel>
    </v-expansion-panels>
  </div>
</template>
<script>
  import { Ipv4PrefixAutocomplete } from 'vuntangle'
  // import { result } from 'lodash'
  import { CONFIG_TYPE } from '../constants'
  import mixin from '../mixin'
  import Util from '../../../../../../util/setupUtil'

  export default {
    components: {
      Ipv4PrefixAutocomplete,
    },
    mixins: [mixin],
    inject: ['$intf', '$status'],
    data() {
      return {
        renewDhcpPending: false,
        CONFIG_TYPE,
        rpc: null,
      }
    },
    computed: {
      status: ({ $status }) => $status(),
      intf: ({ $intf }) => $intf(),
      interfaces: ({ $interfaces }) => $interfaces(),
    },
    async created() {
      this.rpc = await Util.setRpcJsonrpc('admin')
    },

    methods: {
      async onRenewDhcpLease() {
        this.$store.commit('SET_LOADER', true)
        try {
          const [intfIdResult, interfaceStatusResult] = await Promise.all([this.getIntfId(), this.getInterfaceStatus()])

          console.log('intfIdResult :', intfIdResult)
          if (Util.isDestroyed(this)) {
            return
          }
          const intfStatus = interfaceStatusResult.list.find(intfSt => intfSt.interfaceId === this.intf.interfaceId)

          if (intfStatus) {
            const { javaClass, interfaceId, ...rest } = intfStatus
            Object.assign(this.intf, rest) // Update reactive object
            console.log('javaClass : ', javaClass)
            console.log('interfaceId : ', interfaceId)
          }
        } catch (ex) {
          if (!Util.isDestroyed(this)) {
            console.error(ex)
            Util.handleException(ex)
          }
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },

      getIntfId() {
        return new Promise((resolve, reject) => {
          this.rpc.networkManager.renewDhcpLease((result, error) => {
            if (error) {
              reject(error)
            } else {
              resolve(result)
            }
          }, this.intf.interfaceId)
        })
      },
      getInterfaceStatus() {
        return new Promise((resolve, reject) => {
          this.rpc.networkManager.getInterfaceStatus((result, error) => {
            if (error) {
              reject(error)
            } else {
              resolve(result)
            }
          })
        })
      },
    },
  }
</script>
