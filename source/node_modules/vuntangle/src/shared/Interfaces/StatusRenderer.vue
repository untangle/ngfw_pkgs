<template>
  <span>
    <v-icon x-small :color="intf.enabled && status && status.connected ? 'green' : 'grey'">
      {{ intf.enabled ? 'mdi-circle' : 'mdi-circle-off-outline' }}
    </v-icon>
    <span class="d-none d-sm-inline ml-1 text-lowercase">
      {{ $t(intf.enabled ? (status && status.connected ? 'connected' : 'disconnected') : 'disabled') }}
    </span>

    <template v-if="status && status.wan">
      <v-divider vertical class="mx-2" />
      <v-icon x-small :color="online ? 'green' : 'grey'">mdi-wan</v-icon>
      <span class="d-none d-sm-inline ml-1">{{ $t(online ? 'online' : 'offline') }}</span>
    </template>
  </span>
</template>
<script>
  import Vue from 'vue'
  export default Vue.extend({
    data() {
      return {
        showTooltip: false,
      }
    },
    computed: {
      intf: ({ params }) => params.value.intf,
      status: ({ params }) => params.value.status,
      online: ({ status }) => {
        if (!status?.connected) return false
        return !status.offline
      },
    },
  })
</script>
