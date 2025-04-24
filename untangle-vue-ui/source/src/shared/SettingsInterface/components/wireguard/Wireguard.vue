<template>
  <div>
    <p class="font-weight-bold mb-2">{{ $t('configuration') }}</p>
    <u-text-field v-model="pastedConfig" :label="$t('paste_wireguard')" @paste="onPaste" />
    <p class="caption my-2">
      <v-icon style="margin-bottom: 2px" small>mdi-information</v-icon> {{ $t('paste_wireguard_warning') }}
    </p>
    <v-divider class="my-4" />

    <p>
      <!-- LOCAL -->
      <span class="font-weight-bold"> {{ $t('local') }} </span>
      <u-btn
        v-if="intf.wireguardType === 'TUNNEL'"
        text
        outlined
        class="mx-2 font-weight-bold"
        :min-width="null"
        @click="onCopy"
      >
        <v-icon small class="mr-1">mdi-content-copy</v-icon>
        {{ $t('copy_to_clipboard') }}
      </u-btn>
    </p>

    <v-row>
      <v-col>
        <u-text-field :label="$t('public_key')" :disabled="true" :value="intf.wireguardPublicKey" />
      </v-col>
    </v-row>

    <v-row>
      <v-col cols="4">
        <!-- wireguardType -->
        <ValidationProvider v-slot="{ errors }" rules="required">
          <u-select
            v-model="intf.wireguardType"
            :disabled="disableFields"
            :items="typeOptions"
            :label="$t('wireguard_type')"
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-select>
        </ValidationProvider>
      </v-col>
      <v-col>
        <!-- wireguardAddresses[0].address -->
        <ValidationProvider
          v-slot="{ errors }"
          :rules="{
            required: true,
            ip: true,
            unique_wireguard_ipv4: { allInterfaces: interfaces, currentWireguardIntf: intf },
          }"
        >
          <u-text-field v-model="intf.wireguardAddresses[0].address" :label="$t('address')" :error-messages="errors">
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
      <v-col v-if="intf.wireguardType === 'TUNNEL'" cols="3">
        <!-- wireguardPort -->
        <ValidationProvider v-slot="{ errors }" rules="required|port|max:5|max_value:65535">
          <u-text-field
            v-model.number="intf.wireguardPort"
            :label="$t('listen_port')"
            :disabled="disableFields"
            :error-messages="errors"
            type="number"
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
    </v-row>

    <p class="font-weight-bold mt-8">{{ $t('remote') }}</p>
    <!-- The first peer options -->
    <v-row>
      <v-col>
        <!-- wireguardPeers[0].publicKey -->
        <ValidationProvider v-slot="{ errors }" rules="required">
          <u-text-field
            v-model="intf.wireguardPeers[0].publicKey"
            :disabled="disableFields"
            :label="$t('public_key')"
            :error-messages="errors"
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
    </v-row>
    <v-row>
      <v-col>
        <!-- wireguardPeers[0].host -->
        <ValidationProvider v-slot="{ errors }" rules="required|ip">
          <u-text-field
            v-model="intf.wireguardPeers[0].host"
            :disabled="disableFields"
            :label="$t('endpoint_address')"
            :error-messages="errors"
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
      <v-col cols="4">
        <!-- wireguardPeers[0].port -->
        <ValidationProvider v-slot="{ errors }" rules="required|port|max:5|max_value:65535">
          <u-text-field
            v-model.number="intf.wireguardPeers[0].port"
            :label="$t('endpoint_listen_port')"
            :disabled="disableFields"
            :error-messages="errors"
            type="number"
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
    </v-row>

    <v-row>
      <v-col>
        <wireguard-allowed-ips :ips="intf.wireguardPeers[0].allowedIps" v-on="$listeners" />
      </v-col>
    </v-row>
  </div>
</template>
<script>
  import WireguardAllowedIps from './WireguardAllowedIps.vue'

  export default {
    components: { WireguardAllowedIps },
    inject: ['$intf', '$status', '$interfaces'],
    data() {
      return {
        disableFields: false,
        pastedConfig: '',
        wireguardTypeDisabled: false,
        typeOptions: [
          { text: 'Roaming', value: 'ROAMING' },
          { text: 'Tunnel', value: 'TUNNEL' },
        ],
      }
    },
    computed: {
      intf: ({ $intf }) => $intf(),
      interfaces: ({ $interfaces }) => $interfaces(),
      status: ({ $status }) => $status(),
    },

    mounted() {
      this.setWireguardKeypair()
      this.configureAvailableWgIP()
    },

    methods: {
      configureAvailableWgIP() {
        if (!this.intf.new) {
          // Interface edit flow, IP already configured
          return
        }

        // Generate random wireguard address
        this.$emit('get-wireguard-random-address', response => {
          // If the random address is generated assign it to the wireguard address
          if (response?.network) {
            this.intf.wireguardAddresses[0].address = response.network
          }
        })

        const allUsedAddresses = [] // list of already used WG Addresses
        // This is unsaved/new Wireguard Interface
        if (this.intf.wireguardAddresses[0].address) {
          // update list for all used WG addresses
          for (const currentInterface of this.interfaces) {
            if (currentInterface.type === 'WIREGUARD') {
              for (const wgAddress of currentInterface.wireguardAddresses) {
                allUsedAddresses.push(wgAddress.address)
              }
            }
          }

          const nextAvailableAddress = this.getNextAvailableAddress(
            this.intf.wireguardAddresses[0].address,
            this.intf.wireguardAddresses[0].prefix,
            allUsedAddresses.sort(),
          )

          this.intf.wireguardAddresses[0].address = nextAvailableAddress
        }
      },
      getNextAvailableAddress(address, addressSpace, allUsedAddresses) {
        /*
          checks the IP/address-space against the allUsedAddresses
          and returns the first available IP Address the 'allUsedAddresses' that is not used yet
        */
        const currentAddress = address.split('.').map(Number)
        // Calculate the number of available addresses based on the address space
        const availableAddresses = Math.pow(2, 32 - parseInt(addressSpace, 10))

        // Convert the current address to a decimal number
        const decimalAddress =
          (currentAddress[0] << 24) + (currentAddress[1] << 16) + (currentAddress[2] << 8) + currentAddress[3]

        let nextDecimalAddress = decimalAddress
        let newAddress = ''
        while (nextDecimalAddress < availableAddresses) {
          // Convert the decimal address back to the dotted-quad format
          newAddress =
            ((nextDecimalAddress >> 24) & 255) +
            '.' +
            ((nextDecimalAddress >> 16) & 255) +
            '.' +
            ((nextDecimalAddress >> 8) & 255) +
            '.' +
            (nextDecimalAddress & 255)

          if (!allUsedAddresses.includes(newAddress)) {
            return newAddress
          }
          nextDecimalAddress++
        }
        return ''
      },
      setWireguardKeypair() {
        if (!this.intf?.wireguardPrivateKey) {
          this.$emit('get-wireguard-keypair', response => {
            this.intf.wireguardPrivateKey = response?.privateKey
            this.intf.wireguardPublicKey = response?.publicKey
          })
        }
      },

      onPaste(event) {
        const text = event.clipboardData.getData('text/plain')

        this.parseConfiguration(text)

        // clear field after paste, blur is needed to trigger the update
        // set a timeout so the user can tell it was pasted, otherwise it looks like no paste happened
        setTimeout(() => {
          this.pastedConfig = ''
          event.target.blur()
        }, 200)
      },

      async onCopy() {
        const jsonData = {
          hostname: this.intf.name,
          publicKey: this.intf.wireguardPublicKey,
          peerAddress: this.intf.wireguardAddresses[0]?.address || '',
        }

        // if the wireguard is a tunnel, try to get the endpoint address
        if (this.intf.wireguardType === 'TUNNEL') {
          // get the bound interface object
          const boundInterface = this.interfaces.find(intf => this.intf.boundInterfaceId === intf.interfaceId)
          if (!boundInterface) {
            this.$vuntangle.toast.add(this.$t('could_not_find_bound_interface'), 'error')
            return
          }

          // try to get the IPv4 endpoint address
          let address = ''
          if (boundInterface.v4ConfigType === 'STATIC') {
            // for static configuration grab the configured static address
            address = boundInterface.v4StaticAddress
          } else if (boundInterface.v4ConfigType === 'DHCP' || boundInterface.v4ConfigType === 'PPPOE') {
            // for DHCP and PPPoE grab the address from the status of the bound interface
            const response = await this.getResponse(boundInterface)
            address = response?.[0]?.ip4Addr?.[0]?.split('/')[0] || ''
          }
          // if a IPv4 address was not found, try to find an IPv6 address
          if (address === '') {
            if (boundInterface.v6ConfigType === 'STATIC') {
              // for static configuration grab the configured static address
              address = boundInterface.v6StaticAddress
            } else if (boundInterface.v6ConfigType === 'DHCP' || boundInterface.v6ConfigType === 'PPPOE') {
              // for DHCP and PPPoE grab the address from the status of the bound interface
              const response = await this.getResponse(boundInterface)
              address = response?.[0]?.ip6Addr?.[0]?.split('/')[0] || ''
            }
          }

          // add endpoint address if found
          if (address !== '') {
            jsonData.endpointAddress = address
            jsonData.endpointPort = this.intf.wireguardPort
          }
        }
        // If interface is bridged then we do not need to add the network
        const allBridgedToInterfaces = []
        this.interfaces.forEach(intf => {
          if (intf.configType === 'BRIDGED') {
            allBridgedToInterfaces.push(...intf.bridgedInterfaces)
          }
        })

        // get local networks for the JSON
        const networks = []
        this.interfaces.forEach(intf => {
          if (intf.wan === false && intf.enabled === true && !allBridgedToInterfaces.includes(intf.interfaceId)) {
            let netAddr
            if (intf.v4ConfigType === 'STATIC') {
              netAddr = this.getNetworkWithCIDR(intf.v4StaticAddress, intf.v4StaticPrefix)
              networks.push(netAddr + '/' + intf.v4StaticPrefix)
            }
            if (intf.v6ConfigType === 'STATIC') {
              netAddr = this.getNetworkWithCIDR(intf.v6StaticAddress, intf.v6StaticPrefix)
              networks.push(netAddr + '/' + intf.v6StaticPrefix)
            }
          }
        })

        if (networks.length > 0) {
          jsonData.networks = networks.join(',')
        }

        this.$vuntangle.util.copyToClipboard(JSON.stringify(jsonData))
      },

      /**
       * Use the async callback to fetch the address from device status
       *
       * @param {any} boundInterface
       */
      async getResponse(boundInterface) {
        const response = await new Promise(resolve => {
          this.$emit('get-device-status', boundInterface.device, resolve)
        })
        return response
      },

      /**
       * Parse the pasted wireguard text.  First check if it is in a JSON format and convert it to a wireguard
       * config format.  Then loop through each line and parse and set local/remote fields.
       *
       * @param {string} pasteData
       */
      parseConfiguration(pasteData) {
        // check if the data is JSON
        let jsonPasteData
        try {
          jsonPasteData = JSON.parse(pasteData)
        } catch (e) {
          jsonPasteData = null
        }

        // convert JSON format into a wireguard conf file format
        if (jsonPasteData) {
          const remote = ['[Peer]']
          const endpoint = []
          for (const key in jsonPasteData) {
            switch (key) {
              case 'hostname':
                remote.push('# ' + jsonPasteData[key])
                break
              case 'publicKey':
                remote.push('PublicKey=' + jsonPasteData[key])
                break
              case 'endpointAddress':
                endpoint[0] = jsonPasteData[key]
                break
              case 'endpointPort':
                endpoint[1] = jsonPasteData[key]
                break
              case 'networks':
                remote.push('AllowedIps=' + jsonPasteData[key])
                break
            }
          }
          remote.push('Endpoint=' + endpoint.join(':'))
          pasteData = remote.join('\n')
        }

        // loop through key=value lines of the wireguard conf format
        let configured = false
        let privateKeySet = false
        let group = ''
        const lines = pasteData.split('\n')
        for (let line of lines) {
          // remove whitespaces (if any)
          line = line.trim()

          // skip commented out lines
          if (line.startsWith('#')) {
            continue
          }

          // check if the line is just the section type, if so set it for next lines
          if (line.toLowerCase() === '[interface]') {
            group = 'local'
            continue
          }
          if (line.toLowerCase() === '[peer]') {
            group = 'remote'
            continue
          }

          // check to split key/value on equals , skip if not found
          const equalIndex = line.indexOf('=')
          if (equalIndex === -1) {
            continue
          }
          const key = line.slice(0, equalIndex).toLowerCase()
          const value = line.slice(equalIndex + 1)

          // set local settings
          if (group === 'local') {
            const success = this.parseLocalConfLine(key, value)
            if (success) {
              configured = true

              // if what was configured was a private key, set flag to change the 'type'
              if (key === 'privatekey') {
                privateKeySet = true
              }
            }
            continue
          }

          // set remote settings
          if (group === 'remote') {
            const success = this.parseRemoteConfLine(key, value)
            if (success) {
              configured = true
            }
          }
        }

        // if at least one field was configured from the paste, the form fields are no longer editable
        if (configured) {
          // set the wireguard 'type'
          this.intf.wireguardType = privateKeySet ? 'ROAMING' : 'TUNNEL'

          this.disableFields = true
        } else {
          this.$vuntangle.toast.add(this.$t('no_valid_wireguard_settings'), 'error')
        }
      },

      /**
       * Parse a line from the local (interface) section of a wireguard conf file.
       *
       * @param {string} key
       * @param {string} value
       *
       * @returns {boolean} true/false if any form fields were configured
       */
      parseLocalConfLine(key, value) {
        if (key === 'privatekey') {
          if (value === '') {
            return false
          }
          this.$emit('get-wireguard-publickey', value, response => {
            this.intf.wireguardPrivateKey = response?.privateKey
            this.intf.wireguardPublicKey = response?.publicKey
          })
          return true
        }

        if (key === 'address') {
          this.$emit('get-wireguard-address-check', value, response => {
            if (response) {
              this.$vuntangle.toast.add(`Interface IP address - ${response}`, 'error')
              return false
            }
          })
          this.$set(this.intf.wireguardAddresses[0], 'address', value)
          this.$set(this.intf.wireguardAddresses[0], 'prefix', 24)
          return true
        }

        if (key === 'listenport') {
          this.intf.wireguardPort = parseInt(value, 10)
          return true
        }

        return false
      },

      /**
       * Parse a line from the remote (peer) section of a wireguard conf file.
       *
       * @param {string} key
       * @param {string} value
       *
       * @returns {boolean} true/false if any form fields were configured
       */
      parseRemoteConfLine(key, value) {
        if (key === 'publickey') {
          this.$set(this.intf.wireguardPeers[0], 'publicKey', value)
          return true
        }

        if (key === 'endpoint') {
          const [host, port] = value.split(':')
          this.$set(this.intf.wireguardPeers[0], 'host', host)
          this.$set(this.intf.wireguardPeers[0], 'port', parseInt(port, 10))
          return true
        }

        if (key === 'allowedips') {
          const allowedIps = []
          value.split(',').forEach(cidr => {
            let [address, prefix] = cidr.trim().split('/')
            if (address) {
              prefix = prefix ? parseInt(prefix, 10) : 32
              address = this.getNetworkWithCIDR(cidr.split('/')[0], prefix)
              allowedIps.push({ address, prefix })
            }
          })

          // add default 0.0.0.0/0 if it does not exist
          const findIndex = allowedIps.findIndex(allowedIp => allowedIp.address === '0.0.0.0' && allowedIp.prefix === 0)
          if (findIndex === -1) {
            allowedIps.push({ address: '0.0.0.0', prefix: 0 })
          }

          this.$set(this.intf.wireguardPeers[0], 'allowedIps', allowedIps)
          return true
        }

        return false
      },

      /**
       * From the specified IP address and CIDR bit, return the network.
       * For example, 192.168.1.1/24 returns 192.168.1.0
       *
       * @param {*} ip
       * @param {*} cidr
       */
      getNetworkWithCIDR(ip, cidr) {
        const mask = this.getNetmask(cidr)
        return this.getNetworkWithMask(ip, mask)
      },

      /**
       * From the specified IP address and netmask, return the network.
       * For example, 192.168.1.1/255.255.255.0 returns 192.168.1.0
       *
       * @param {*} ip
       * @param {*} netmask
       */
      getNetworkWithMask(ip, netmask) {
        let dots = netmask.split('.')
        const netmaskInteger = ((+dots[0] * 256 + +dots[1]) * 256 + +dots[2]) * 256 + +dots[3]
        dots = ip.split('.')
        const ipInteger = (((+dots[0] * 256 + +dots[1]) * 256 + +dots[2]) * 256 + +dots[3]) & netmaskInteger
        return (
          (ipInteger >>> 24) +
          '.' +
          ((ipInteger >> 16) & 255) +
          '.' +
          ((ipInteger >> 8) & 255) +
          '.' +
          (ipInteger & 255)
        )
      },

      /**
       * From a given CIDR bitcount, get the appropriate netmask
       *
       * @param {*} bitCount - the CIDR bitcount (ie: 32)
       */
      getNetmask(bitCount) {
        const mask = []
        for (let i = 0; i < 4; i++) {
          const n = Math.min(bitCount, 8)
          mask.push(256 - Math.pow(2, 8 - n))
          bitCount -= n
        }
        return mask.join('.')
      },
    },
  }
</script>
