<template>
  <v-card flat class="ma-0 text--secondary">
    <h4 v-if="!affectedInterfaces.length" v-html="$t('delete_interface_confirm', [intf.name])" />

    <!-- bridged interfaces -->
    <div v-if="affectedInterfaces.length" class="mb-4">
      <p class="ma-0 font-weight-medium">
        {{ $t('following_interfaces_have_this_as_bridged_to') }}
      </p>
      <ul>
        <li v-for="iface in affectedInterfaces" :key="iface">
          <span v-html="$t('interface_is_bridged_to', [iface, intf.name])" />
        </li>
      </ul>
    </div>
  </v-card>
</template>
<script>
  export default {
    props: {
      intf: { type: Object, default: () => null },
      affectedInterfaces: { type: Array, default: () => [] },
    },

    methods: {
      async action() {
        this.$emit('progress-show')
        /* Passing selected intf to the deleteInterface from store
         *deleteInterface will handle for remove selected interface from all the interfaces
         * Updated Interfaces will be passed to the Network Setting
         */
        const response = await this.$store.dispatch('config/deleteInterface', this.intf)
        if (response) {
          this.$vuntangle.toast.add(this.$t('deleted_successfully', [this.$t('interface')]))
          // notify consumer of success
          this.$emit('update')
        } else {
          this.$vuntangle.toast.add(this.$t('unable_to_save', [response.message]))
        }

        this.$emit('progress-hide')
        this.$emit('close')
      },
    },
  }
</script>
