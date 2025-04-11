<template>
  <span>
    <v-icon x-small :color="status && status.connected === 'CONNECTED' ? 'green' : 'grey'">
      {{ status.connected === 'CONNECTED' ? 'mdi-circle' : 'mdi-circle-off-outline' }}
    </v-icon>
    <span class="d-none d-sm-inline ml-1 text-lowercase">
      {{ $t(status.connected ? (status.connected === 'CONNECTED' ? 'connected' : 'disconnected') : 'disabled') }}
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
    mounted() {},
  })
</script>
