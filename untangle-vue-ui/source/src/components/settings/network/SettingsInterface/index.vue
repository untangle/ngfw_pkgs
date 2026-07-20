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
  import cloneDeep from 'lodash/cloneDeep'
  import settingsMixin from '../../settingsMixin'
  import Common from './components/Common.vue'
  import defaults from './defaults'

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
        $intf: () => this.settingsCopy,
        $interfaces: () => this.interfaces,
        $interfaceStatuses: () => this.interfaceStatuses,
        $status: () => this.status,
        $disabled: () => this.disabled,
        $onDelete: () => this.$emit('delete'),
      }
    },
    props: {
      settings: { type: Object, default: () => null },
      interfaces: { type: Array, default: () => [] },
      type: { type: String, default: () => null },
      disabled: { type: Boolean, default: () => false },
      isSaving: { type: Boolean, default: false },
      interfaceStatuses: { type: Array, default: () => [] },
    },
    data() {
      return {
        intf: null,
        status: null,
        settingsCopy: null,
      }
    },
    computed: {
      device: ({ $route }) => $route.params.device,
      // interfaceStatuses: ({ $store }) => $store.getters['config/interfaceStatuses'],
      title() {
        if (!this.device && this.type === 'VLAN') {
          return this.$t('add_x_interface', [this.$t('vlan')])
        } else {
          return this.$t('edit_interface', [`${this.settingsCopy.name} (${this.settingsCopy.systemDev})`])
        }
      },
    },

    created() {
      if (this.device) {
        // Edit mode
        const found = this.interfaces.find(i => i.systemDev === this.device)
        this.settingsCopy = found ? cloneDeep(found) : {}
        this.status = this.interfaceStatuses.find(i => i.systemDev === this.device) || {}
      } else if (this.type && defaults[this.type?.toLowerCase()]) {
        // New mode
        this.settingsCopy = cloneDeep(defaults[this.type?.toLowerCase()])
        this.status = {}
      } else {
        this.settingsCopy = {}
        this.status = {}
      }
    },
    methods: {
      async validate() {
        const isValid = await this.$refs.common.validate()
        return isValid
      },
    },
  }
</script>
