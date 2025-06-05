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
        $onDelete: () => this.$emit('delete'),
      }
    },
    props: {
      settings: { type: Object, default: () => null },
      interfaces: { type: Array, default: () => [] },
      disabled: { type: Boolean, default: () => false },
      isSaving: { type: Boolean, default: false },
      interfaceStatuses: { type: Array, default: () => [] },
    },
    data() {
      return {
        intf: null,
        status: null,
      }
    },
    computed: {
      device: ({ $route }) => $route.params.device,
      title() {
        // when editing existing intf use original settings for title
        if (this.intf) {
          return this.$t('edit_interface', [`${this.intf.name} (${this.intf.systemDev})`])
        }
        return 'Edit Interface'
      },
    },
    created() {
      this.intf = this.device ? this.interfaces.find(i => i.systemDev === this.device) : {}
      this.status = this.device ? this.interfaceStatuses.find(i => i.systemDev === this.device) : {}
    },

    methods: {
      async validate() {
        const isValid = await this.$refs.common.validate()
        return isValid
      },
    },
  }
</script>
