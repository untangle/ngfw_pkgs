<!--
  component for editing local and remote network settings for IPsec service/tunnel
-->
<template>
  <div>
    <v-checkbox
      v-model="ipsec.singleSubnetNegotiation"
      :label="$t('ipsec_single_subnet_negotiation')"
      class="mb-4 mt-0"
      hide-details
    />
    <v-row class="mt-4">
      <v-col>
        <p class="font-weight-bold mb-2">{{ $t('local_gateway') }}</p>

        <div class="d-flex align-center">
          <ValidationProvider v-slot="{ errors }" :rules="localGatewayRules">
            <v-radio-group v-model="localGateway" row hide-details class="my-2 py-0">
              <v-radio value="any" :label="$t('any')" />
              <v-radio v-if="selectedWan" value="wan" :label="`${selectedWan.name}`" />
              <v-radio v-if="selectedWan" value="custom" :label="$t('custom')" />
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </v-radio-group>
          </ValidationProvider>

          <v-spacer />

          <span v-if="selectedWan && localGateway === 'wan'">{{ selectedWan.address }}</span>

          <!-- local gateway IP address -->
          <ValidationProvider
            v-if="localGateway === 'custom'"
            v-slot="{ errors }"
            :rules="{ required: localGateway === 'custom', ip: localGateway === 'custom' }"
            class="flex-grow-1"
          >
            <u-text-field
              v-model="ipsec.local.gateway"
              :error-messages="errors"
              :disabled="localGateway !== 'custom'"
              :placeholder="localGateway === 'custom' ? $t('ipv4_address') : ''"
            >
              <template v-if="errors.length" #append>
                <u-errors-tooltip :errors="errors" />
              </template>
            </u-text-field>
          </ValidationProvider>
        </div>

        <br />
        <p class="font-weight-bold mb-2">{{ $t('local_networks') }}</p>

        <v-checkbox v-model="fullTunnelLocal" :label="$t('full_tunnel_mode')" class="mb-4 mt-0" hide-details />

        <u-alert v-if="fullTunnelLocal && ipsec.local.networks.length > 1">
          <span>{{ $t('ipsec_full_tunnel_local_info') }}</span>
        </u-alert>

        <u-alert v-if="!ipsec.local.networks.length" class="mb-1">
          <span>{{ $t('no_networks_defined') }}</span>
        </u-alert>

        <!-- MFW-1963 using a hidden component to handle validation for at least one local network to be defined -->
        <ValidationProvider v-slot="{ errors }" rules="min_value: 1">
          <u-text-field v-model="ipsec.local.networks.length" type="number" class="d-none" />
          <!-- as the component is hidden, using an alert above the grid to show it -->
          <u-alert v-if="errors.length" error>{{ $t('ipsec_local_networks_required') }}</u-alert>
        </ValidationProvider>

        <draggable v-model="ipsec.local.networks" v-bind="dragOptions" @start="drag = true" @end="drag = false">
          <transition-group>
            <ipsec-network-item
              v-for="(item, index) in ipsec.local.networks"
              :key="item.network + item.prefix"
              :ipsec="ipsec"
              :index="index"
              :item="item"
              type="local"
              :full-tunnel="fullTunnelLocal"
            />
          </transition-group>
        </draggable>

        <div class="d-flex align-center">
          <span v-if="!fullTunnelLocal && ipsec.local.networks.length > 1" class="caption grey--text">
            {{ $t('ipsec_networks_drag') }}
          </span>
          <v-spacer />
          <u-btn class="my-2" :disabled="fullTunnelLocal" @click="onEdit(-1, 'local')">
            {{ $t('add_local_network') }}
          </u-btn>
        </div>
      </v-col>

      <v-divider vertical class="mx-8" />

      <v-col>
        <p class="font-weight-bold mb-2">{{ $t('remote_gateway') }}</p>

        <div class="d-flex align-center">
          <ValidationProvider v-slot="{ errors }" :rules="remoteGatewayRules">
            <v-radio-group v-model="remoteGateway" row hide-details class="my-2 py-0">
              <v-radio value="any" :label="$t('any')" />
              <v-radio value="custom" :label="$t('custom')" />
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </v-radio-group>
          </ValidationProvider>

          <!-- remote gateway IP address -->
          <ValidationProvider
            v-slot="{ errors }"
            :rules="{ required: remoteGateway === 'custom', ip: remoteGateway === 'custom' }"
            class="flex-grow-1"
          >
            <u-text-field
              v-if="remoteGateway !== 'any'"
              v-model="ipsec.remote.gateway"
              :error-messages="errors"
              :disabled="remoteGateway !== 'custom'"
              :placeholder="remoteGateway === 'custom' ? $t('ipv4_address') : ''"
              autocomplete="one-time-code"
            >
              <template v-if="errors.length" #append>
                <u-errors-tooltip :errors="errors" />
              </template>
            </u-text-field>
          </ValidationProvider>
        </div>

        <br />
        <p class="font-weight-bold mb-2">{{ $t('remote_networks') }}</p>

        <v-checkbox v-model="fullTunnelRemote" :label="$t('full_tunnel_mode')" class="mb-4 mt-0" hide-details />

        <u-alert v-if="fullTunnelRemote && ipsec.remote.networks.length > 1">
          <span class="body-2">{{ $t('ipsec_full_tunnel_remote_info') }}</span>
        </u-alert>

        <u-alert v-if="!ipsec.remote.networks.length" class="mb-1">
          <span>{{ $t('no_networks_defined') }}</span>
        </u-alert>

        <!-- MFW-1963 using a hidden component to handle validation for at least one remote network to be defined -->
        <ValidationProvider v-slot="{ errors }" rules="min_value: 1">
          <u-text-field v-model="ipsec.remote.networks.length" type="number" class="d-none" />
          <!-- as the component is hidden, using an alert above the grid to show it -->
          <u-alert v-if="errors.length" error>{{ $t('ipsec_remote_networks_required') }}</u-alert>
        </ValidationProvider>

        <draggable v-model="ipsec.remote.networks" v-bind="dragOptions" @start="drag = true" @end="drag = false">
          <transition-group>
            <ipsec-network-item
              v-for="(item, index) in ipsec.remote.networks"
              :key="item.network + item.prefix"
              :ipsec="ipsec"
              :index="index"
              :item="item"
              type="remote"
              :full-tunnel="fullTunnelRemote"
            />
          </transition-group>
        </draggable>

        <div class="d-flex align-center">
          <span v-if="!fullTunnelRemote && ipsec.remote.networks.length > 1" class="caption grey--text">
            {{ $t('ipsec_networks_drag') }}
          </span>
          <v-spacer />
          <u-btn class="my-2" :disabled="fullTunnelRemote" @click="onEdit(-1, 'remote')">
            {{ $t('add_remote_network') }}
          </u-btn>
        </div>
      </v-col>
    </v-row>
  </div>
</template>
<script>
  import draggable from 'vuedraggable'
  import defaults from '../../defaults'
  import mixin from '../mixin'
  import IpsecNetworkItem from './IpsecNetworkItem.vue'
  import IpsecNetworkDialog from './IpsecNetworkDialog.vue'

  export default {
    components: { draggable, IpsecNetworkItem },
    mixins: [mixin],
    inject: ['$intf', '$interfaces', '$onGetAllInterfaceStatus'],
    data() {
      return {
        remoteGatewayIp: '', // keeps a copy of an existing remote gateway IP
        selectedWan: null,
        drag: false,
        interfaceStatusAll: [],
      }
    },

    computed: {
      intf: ({ $intf }) => $intf(),
      interfaces: ({ $interfaces }) => $interfaces(),
      ipsec: ({ intf }) => intf.ipsec,
      device: ({ intf }) => intf.device,
      boundInterfaceId: ({ intf }) => intf.boundInterfaceId,

      dragOptions() {
        return {
          animation: 200,
          group: 'description',
          disabled: false,
          ghostClass: 'ghost',
        }
      },

      /**
       * localGateway is used to compute the final ipsec.local.gateway
       * based on selection and bound interface
       * */
      localGateway: {
        get() {
          const gateway = this.ipsec.local.gateway
          if (gateway === '%any') return 'any'
          if (gateway === this.selectedWan?.address) return 'wan'
          return 'custom'
        },
        set(value) {
          if (value === 'any') {
            this.ipsec.local.gateway = '%any'
          }
          if (value === 'wan') {
            this.ipsec.local.gateway = this.selectedWan.address
          }
          if (value === 'custom') {
            this.ipsec.local.gateway = null
          }
        },
      },

      /**
       * remoteGateway is used to compute the final ipsec.remote.gateway
       * */
      remoteGateway: {
        get() {
          const gateway = this.ipsec.remote.gateway
          if (gateway === '%any') return 'any'
          return 'custom'
        },
        set(value) {
          if (value === 'any') {
            this.remoteGatewayIp = this.ipsec.remote.gateway
            this.ipsec.remote.gateway = '%any'
          }
          if (value === 'custom') {
            this.ipsec.remote.gateway = this.remoteGatewayIp
          }
        },
      },

      fullTunnelLocal: {
        get() {
          return this.ipsec.local.networks.findIndex(n => n.network === '0.0.0.0' && n.prefix === 0) >= 0
        },
        set(value) {
          if (value) {
            if (this.fullTunnelRemote) {
              this.ipsec.remote.networks.shift()
            }
            this.ipsec.local.networks.unshift(defaults.ipsec_network)
          } else {
            this.ipsec.local.networks.shift()
          }
        },
      },

      fullTunnelRemote: {
        get() {
          return this.ipsec.remote.networks.findIndex(n => n.network === '0.0.0.0' && n.prefix === 0) >= 0
        },
        set(value) {
          if (value) {
            if (this.fullTunnelLocal) {
              this.ipsec.local.networks.shift()
            }
            this.ipsec.remote.networks.unshift(defaults.ipsec_network)
          } else {
            this.ipsec.remote.networks.shift()
          }
        },
      },
    },

    watch: {
      /**
       * MFW-2062
       * Watcher that sets local gateway based on bound interface wan selection
       */
      boundInterfaceId: {
        immediate: true,
        /**
         * Watcher handler
         * @param {Number} id - the bound interface id
         */
        handler(id) {
          // upon creation no WAN selected
          if (id === null || id === 0) {
            this.ipsec.local.gateway = '%any'
            this.selectedWan = null
            return
          }

          const intfStatus = this.interfaceStatusAll?.find(intf => intf.interfaceId === id)
          if (!intfStatus) return

          const wanIp = this.getWanIp(intfStatus)

          // specific wan selected
          if (id > 0) {
            this.selectedWan = {
              name: intfStatus?.name,
              address: wanIp,
            }

            // populate local gateway with selected wan
            this.ipsec.local.gateway = this.selectedWan.address

            // checks if current local gateway matches one of the wans, and updates it value based on selection
            this.boundToOptions.forEach(opt => {
              const wanStatus = this.interfaceStatusAll?.find(stat => stat.name === opt.text)
              if (this.ipsec.local.gateway === this.getWanIp(wanStatus)) {
                this.ipsec.local.gateway = this.selectedWan.address
              }
            })
          }
        },
      },
    },

    mounted() {
      /**
       * if device is null than action is to add a new interface
       * so local networks are populated from available non-WANs
       */
      this.$onGetAllInterfaceStatus(resp => {
        this.interfaceStatusAll = resp
        if (!this.device) {
          this.addLocalNetworks()
        }
      })

      /**
       * keeps a copy of an existing remote gateway IP to be reused in case
       * of switching back and forth `%any` address
       */
      this.remoteGatewayIp = this.ipsec.remote.gateway !== '%any' ? this.ipsec.remote.gateway : ''
    },

    methods: {
      /**
       * Extracts IPv4 address from status of a given interface
       * @param {Object} status
       */
      getWanIp(status) {
        if (!status || !status.ip4Addr || status.ip4Addr?.length === 0) {
          return ''
        }
        return status.ip4Addr[0]?.split('/')[0] || ''
      },

      /**
       * Populates Local Networks with available non-WANs for a new IPsec tunnel
       */
      addLocalNetworks() {
        const localNetworks = []

        if (!this.interfaceStatusAll?.length) {
          return
        }
        this.interfaceStatusAll.forEach(intf => {
          // exclude WANs or bridged interfaces
          if (intf.wan || intf.configType === 'BRIDGED' || !intf.ip4Addr?.length) {
            return
          }

          const ip = intf.ip4Addr[0] || null
          const network = ip?.split('/')[0] || ''
          const prefix = ip?.split('/')[1] ? parseInt(ip?.split('/')[1]) : 24

          if (network && prefix) {
            // get the subnet for the address/prefix
            const subnet = this.$vuntangle.net.info(network, prefix)
            localNetworks.push({
              network: subnet.networkAddress,
              prefix: subnet.cidr,
            })
          }
        })
        this.ipsec.local.networks = localNetworks
      },

      /**
       * Shows an editing dialog for network
       * @param {Number} index - the index of the network being edited (-1 means new)
       * @param {String} grid - for which network (local or remote)
       */
      onEdit(index, grid) {
        this.$vuntangle.dialog.show({
          title: index === -1 ? this.$t(`add_${grid}_network`) : this.$t(`edit_${grid}_network`),
          component: IpsecNetworkDialog,
          width: 600,
          actionLabel: index === -1 ? this.$t('add') : this.$t('update'),
          componentProps: {
            type: grid, // type: 'local' or 'remote'
            ipsec: this.ipsec,
            index,
          },
        })
      },

      /**
       * Removes a network from list
       * @param {Number} index - the index of the network to be removed
       * @param {String} grid - from which side (local or remote)
       */
      onDelete(index, grid) {
        this.ipsec[grid].networks.splice(index, 1)
      },
    },
  }
</script>
