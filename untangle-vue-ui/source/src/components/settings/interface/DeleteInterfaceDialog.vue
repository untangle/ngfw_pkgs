<template>
  <v-card flat class="ma-0 text--secondary">
    <h4 v-if="!affectedChildInterfaces.length" v-html="$t('delete_interface_confirm', [intf.name])" />
  </v-card>
</template>
<script>
  export default {
    props: {
      intf: { type: Object, default: () => null },
      affectedChildInterfaces: { type: Array, default: () => [] },
    },
    methods: {
      async action() {
        this.$emit('progress-show')
        /* Passing selected intf to the deleteInterface from store
         *deleteInterface will handle for remove selected interface from all the interfaces
         * Updated Interfaces will be passed to the Network Setting
         */
        const response = await this.$store.dispatch('settings/deleteInterface', this.intf)
        if (response) {
          this.$vuntangle.toast.add(this.$t('deleted_successfully', [this.$t('interface')]))
          // notify consumer of success
          this.$emit('update')
        }

        this.$emit('progress-hide')
        this.$emit('close')
      },
    },
  }
</script>
