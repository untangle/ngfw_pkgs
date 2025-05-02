<!--
  dialog component for editing IPsec local/remote networks
-->
<template>
  <div>
    <ValidationObserver ref="obs">
      <v-row class="my-0">
        <v-col>
          <!-- IP address -->
          <ValidationProvider
            v-slot="{ errors }"
            :rules="{
              required: true,
              ip: true,
              unique_insensitive: { list: conflictIps, message: $t('ipsec_network_ip_conflict') },
            }"
          >
            <u-text-field
              v-model="entry.network"
              :label="$t('ip_address')"
              :error-messages="errors"
              class="mr-4"
              @keydown.space="event => event.preventDefault()"
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
        <v-col>
          <!-- prefix -->
          <ValidationProvider v-slot="{ errors }" rules="required">
            <ipv-4-prefix-autocomplete v-model="entry.prefix" :min="0" :errors="errors" />
          </ValidationProvider>
        </v-col>
      </v-row>
    </ValidationObserver>

    <!-- suggested subnet based on user input that will be forced upon add/edit -->
    <u-alert v-if="!overlappingSubnet && suggestedNetwork && suggestedNetwork.networkAddress !== entry.network">
      <span
        v-html="$t('ipsec_subnet_suggested_network', [`${suggestedNetwork.networkAddress}/${suggestedNetwork.cidr}`])"
      />
    </u-alert>

    <!-- error display for conflicting networks -->
    <u-alert v-if="overlappingSubnet" error>
      {{ $t(`ipsec_subnet_${type === 'local' ? 'remote' : 'local'}_conflict`, [overlappingSubnet]) }}
    </u-alert>
  </div>
</template>
<script>
  import cloneDeep from 'lodash/cloneDeep'
  import Ipv4PrefixAutocomplete from '../../../../components/Ipv4PrefixAutocomplete'

  export default {
    components: {
      Ipv4PrefixAutocomplete,
    },
    props: {
      type: { type: String, default: null }, // 'local' or 'remote'
      ipsec: { type: Object, default: () => null }, // full ipsec object
      index: { type: Number, default: -1 }, // editing network index
    },

    data: () => ({
      // default network ip/prefix entry
      entry: { network: '', prefix: 24 },
      overlappingSubnet: null,
      suggestedNetwork: null,
    }),

    computed: {
      /**
       * returns existing local/remote networks IPs
       * used to validate against conflicting entry
       */
      conflictIps() {
        const ips = []
        this.ipsec.local.networks.forEach(n => {
          // exclude local editing IP
          if (this.type === 'local' && this.index >= 0 && this.entry.network === n.network) {
            return
          }
          ips.push(n.network)
        })
        this.ipsec.remote.networks.forEach(n => {
          // exclude remote editing IP
          if (this.type === 'remote' && this.index >= 0 && this.entry.network === n.network) {
            return
          }
          ips.push(n.network)
        })
        return ips
      },
    },

    watch: {
      entry: {
        deep: true,
        handler(value) {
          // MFW-2023 when setting network 0.0.0.0, automatically set prefix to 0
          if (value.network === '0.0.0.0') {
            value.prefix = 0
          }
          // gets the subnet of an address entry
          this.suggestedNetwork = this.$vuntangle.net.info(value.network, value.prefix)
        },
      },
    },

    created() {
      // populate entry when editing a network
      if (this.index >= 0) {
        this.entry = cloneDeep(this.ipsec[this.type].networks[this.index])
      }
    },

    methods: {
      /**
       * Check if added/edited local/remote network conflicts (overlaps)
       * with already defined remote/local networks
       */
      checkOverlappingSubnet() {
        this.overlappingSubnet = null
        const networks = this.type === 'local' ? this.ipsec.remote.networks : this.ipsec.local.networks
        networks.forEach(n => {
          // skip check if 0.0.0.0/0 network
          if (n.network === '0.0.0.0' && n.prefix === 0) {
            return
          }
          const existingSubnet = `${n.network}/${n.prefix}`
          const newSubnet = `${this.entry.network}/${this.entry.prefix}`

          const conflict = this.$vuntangle.net.subnetConflict(existingSubnet, newSubnet)
          if (!this.overlappingSubnet && conflict) {
            this.overlappingSubnet = existingSubnet
          }
        })
      },

      async action() {
        const isValid = await this.$refs.obs.validate()
        if (!isValid) return

        const isFullTunnel = this.entry.network === '0.0.0.0' && this.entry.prefix === 0

        // check subnet conflicts, but skip 0.0.0.0/0
        if (!isFullTunnel) {
          this.checkOverlappingSubnet()
          if (this.overlappingSubnet) {
            return
          }
        }

        // use actual subnets instead of given addresses
        this.entry.network = this.suggestedNetwork.networkAddress
        this.entry.prefix = parseInt(this.suggestedNetwork.cidr)

        // cloning to be able to mutate list
        const networksClone = cloneDeep(this.ipsec[this.type].networks)

        if (this.index > -1) {
          networksClone[this.index] = this.entry // update entry
        } else if (isFullTunnel) {
          networksClone.unshift(this.entry) // add first 0.0.0.0/0
        } else {
          networksClone.push(this.entry) // add last new entry
        }

        this.$set(this.ipsec[this.type], 'networks', networksClone)
        this.$emit('close')
      },
    },
  }
</script>
