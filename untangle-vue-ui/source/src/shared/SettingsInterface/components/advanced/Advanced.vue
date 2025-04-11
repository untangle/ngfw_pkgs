<template>
  <div>
    <div v-if="showNICOptions" class="mt-4">
      <h4 class="mb-4">{{ $vuntangle.$t('nic_options') }}</h4>
      <p v-if="status" v-html="$vuntangle.$t('interface_advanced_status', [status.ethSpeed, status.ethDuplex])" />

      <v-checkbox v-model="intf.ethAutoneg" :label="$vuntangle.$t('auto_negotiation')" />

      <v-row v-if="status">
        <v-col>
          <u-select
            v-model="intf.ethSpeed"
            :items="speedOptions"
            :label="$vuntangle.$t('link_speed')"
            suffix="Mbps"
            :disabled="intf.ethAutoneg"
          />
        </v-col>
        <v-col>
          <u-select
            v-model="intf.ethDuplex"
            :items="duplexOptions"
            :label="$vuntangle.$t('duplex_mode')"
            :disabled="intf.ethAutoneg"
          />
        </v-col>
      </v-row>
    </div>
    <div class="mt-4">
      <p class="font-weight-bold mb-4">{{ $vuntangle.$t('maximum_transmission_unit') }}</p>
      <div>
        <u-alert v-if="isMtuDisabled" info class="mt-4 mb-4">
          <span v-html="$vuntangle.$t('mtu_settings_edit')"></span>
        </u-alert>
      </div>

      <v-row class="align-center">
        <v-col cols="2">
          <u-checkbox
            v-model="routeMtu"
            :disabled="isMtuDisabled"
            :label="$vuntangle.$t('use_route_mtu')"
            hide-details
            class="ma-0 mr-2"
          />
        </v-col>
        <v-col cols="3">
          <ValidationProvider v-slot="{ errors }" :rules="mtuRules">
            <u-text-field
              v-model="mtu"
              :label="$vuntangle.$t('mtu')"
              :disabled="isMtuDisabled || routeMtu"
              type="number"
              :suffix="$vuntangle.$t('bytes')"
              :error-messages="errors"
              @keydown="preventEKey"
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
      </v-row>
    </div>
    <status-analyzer-info v-if="intf.interfaceId && intf.wan" :interface-id="intf.interfaceId" class="mt-4" />
  </div>
</template>
<script>
  import { VRow, VCol, VCheckbox } from 'vuetify/lib'
  import StatusAnalyzerInfo from '../ipsec/StatusAnalyzerInfo.vue'
  import { MTU_VALUES } from '../constants'
  import mixin from '../mixin'

  export default {
    components: { VCheckbox, VRow, VCol, StatusAnalyzerInfo },
    mixins: [mixin],
    inject: ['$intf', '$status', '$interfaces'],

    computed: {
      intf: ({ $intf }) => $intf(),
      interfaces: ({ $interfaces }) => $interfaces(),
      status: ({ $status }) => $status(),

      isMtuDisabled: ({ intf }) => intf.type === 'VLAN',
      parentInterface: ({ intf, interfaces }) => interfaces.find(iface => iface.interfaceId === intf.boundInterfaceId),

      /** computes duplex options (`full`, `half`) based on interface status supported link */
      duplexOptions: ({ status }) => {
        if (!status || !status.ethLinkSupported) return []

        const options = []
        const initials = []

        status.ethLinkSupported.forEach(link => {
          const i = link.slice(-1) // `F` or `H`
          if (!initials.includes(i)) {
            initials.push(i)
          }
        })

        initials.forEach(i => {
          if (i === 'H') options.push({ value: 'half', text: 'half' })
          if (i === 'F') options.push({ value: 'full', text: 'full' })
        })
        return options
      },

      /** computes speed options (10, 100, 1000 ...) based on interface status supported link */
      speedOptions: ({ status }) => {
        if (!status || !status.ethLinkSupported) return []

        const options = []
        const speeds = []

        status.ethLinkSupported.forEach(link => {
          const s = parseInt(link, 10)
          if (!speeds.includes(s)) {
            speeds.push(s)
          }
        })
        speeds.forEach(s => {
          options.push({ value: s, text: s })
        })
        return options
      },
      mtu: {
        get: ({ intf, parentInterface }) =>
          intf.type === 'VLAN' ? parentInterface?.mtu || MTU_VALUES.DEFAULT : intf.mtu || MTU_VALUES.DEFAULT,
        set(value) {
          this.$set(this.intf, 'mtu', parseInt(value))
        },
      },
      routeMtu: {
        get: ({ intf, parentInterface }) => (intf.type === 'VLAN' ? !!parentInterface?.routeMtu : !!intf.routeMtu),
        set(value) {
          if (value && (this.mtu < MTU_VALUES.MIN || this.mtu > MTU_VALUES.MAX)) {
            this.mtu = MTU_VALUES.DEFAULT
          }
          this.$set(this.intf, 'routeMtu', value)
        },
      },
      mtuRules: ({ routeMtu }) =>
        !routeMtu ? { required: true, min_value: MTU_VALUES.MIN, max_value: MTU_VALUES.MAX } : null,
    },

    methods: {
      preventEKey(event) {
        // Define the allowed keys
        const allowedKeys = [
          '0',
          '1',
          '2',
          '3',
          '4',
          '5',
          '6',
          '7',
          '8',
          '9',
          'Backspace',
          'Shift',
          'ArrowLeft',
          'ArrowRight',
        ]

        // Check if the pressed key is in the list of allowed keys
        if (!allowedKeys.includes(event.key)) {
          event.preventDefault()
        }
      },
    },
  }
</script>
