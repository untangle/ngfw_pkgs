<template>
  <v-container
    :fluid="classicView ? true : false"
    :class="`${classicView ? 'pa-4 ' : ''}shared-cmp d-flex flex-column flex-grow-1`"
  >
    <slot name="no-license"></slot>
    <slot name="bridged-interface"></slot>
    <div class="d-flex align-center">
      <h1 v-if="classicView" class="headline" v-html="title" />
      <h2 v-else class="font-weight-light" v-html="title" />
      <v-spacer />
      <slot name="actions" :new-settings="settingsCopy" :is-dirty="isDirty" :validate="validate"></slot>
    </div>

    <v-divider class="my-2" />

    <common ref="common" v-on="$listeners" />
  </v-container>
</template>
<script>
  import settingsMixin from '../../settingsMixin'
  import Common from './components/Common.vue'

  export default {
    components: {
      Common,
    },
    mixins: [settingsMixin],
    /**
     * use provide with the reactive data settings
     * that gets injected into all descendent components
     */
    provide() {
      return {
        $isSaving: () => this.isSaving,
        $intf: () => this.intf,
        $interfaces: () => this.interfaces,
        $interfaceStatuses: () => this.interfaceStatuses,
        $status: () => this.status,
        $disabled: () => this.disabled,
        $interfaceTrackers: () => this.interfaceTrackers,
        // $onManageStatusAnalyzers: () => this.$emit('manage-status-analyzers'),
        $onDelete: () => this.$emit('delete'),
        // $onRenewDhcp: (device, cb) => this.$emit('renew-dhcp', device, () => cb()),
        $onGetAllInterfaceStatus: cb => this.$emit('get-all-interface-status', res => cb(res)),
      }
    },
    props: {
      settings: { type: Object, default: () => null },
      interfaces: { type: Array, default: () => [] },
      type: { type: String, default: () => null },
      status: { type: Object, default: () => null },
      disabled: { type: Boolean, default: () => false },
      interfaceTrackers: { type: Array, default: () => [] },
      isSaving: { type: Boolean, default: false },
      interfaceStatuses: { type: Array, default: () => [] },
    },
    data() {
      return {
        intf: null,
      }
    },
    computed: {
      device: ({ $route }) => $route.params.device,
      // interfaceStatuses: ({ $store }) => $store.getters['settings/interfaceStatuses'],
      title() {
        // when editing existing intf use original settings for title
        if (this.intf) {
          return this.$t('edit_interface', [`${this.intf.name} (${this.intf.physicalDev})`])
        }
        // when adding a new intf use cloned intf type for the title
        // switch (this.settingsCopy.type) {
        //   case 'VLAN':
        //     return this.$t('add_x_interface', [this.$t('vlan')])
        //   case 'WIREGUARD':
        //     return this.$t('add_x_interface', [this.$t('wireguard')])
        //   case 'OPENVPN':
        //     return this.$t('add_x_interface', [this.$t('open_vpn')])
        //   case 'IPSEC':
        //     return this.$t('add_x_interface', [this.$t('ipsec_tunnel')])
        //   case 'BRIDGE':
        //     return this.$t('add_x_interface', [this.$t('bridge')])
        // }
        return 'Edit Interface'
      },
    },
    mounted() {
      console.log('interfaces inside index', this.interfaces)
      console.log('interfaceStatuses inside index', this.interfaceStatuses)
      // console.log('intf inside index', this.intf)
    },
    created() {
      this.intf = this.device ? this.interfaceStatuses.find(i => i.physicalDev === this.device) : {}
      console.log('intf inside index', this.intf)
      console.log('settings inside index', this.settings)
      // cloning the defaults so they do not get mutated
      // if (this.type && defaults[this.type]) this.settingsCopy = cloneDeep(defaults[this.type])
    },

    methods: {
      async validate() {
        const isValid = await this.$refs.common.validate()
        return isValid
      },
    },
  }
</script>
