<template>
  <u-widget
    :title="$t('network_information')"
    :enable-expand="false"
    :fetching="fetching"
    enable-refresh
    @refresh="loadData"
  >
    <div class="d-flex flex-column" style="height: 100%">
      <div class="pa-2 pt-4">
        <div class="d-flex justify-space-around text-center">
          <div class="flex-grow-1">
            <div class="body-2 black--text mb-1">{{ $t('currently_active') }}</div>
            <div class="text-h6 font-weight-bold">{{ stats.activeHosts ?? '-' }}</div>
          </div>
          <div class="flex-grow-1">
            <div class="body-2 black--text mb-1">{{ $t('maximum_active') }}</div>
            <div class="text-h6 font-weight-bold">{{ stats.maxActiveHosts ?? '-' }}</div>
          </div>
          <div class="flex-grow-1">
            <div class="body-2 black--text mb-1">{{ $t('known_devices') }}</div>
            <div class="text-h6 font-weight-bold">{{ stats.knownDevices ?? '-' }}</div>
          </div>
        </div>
        <div class="d-flex px-4 pt-2 pb-2" style="gap: 8px">
          <div class="flex-grow-1">
            <v-btn small block color="#7cb5ec" class="text-none" @click="navigate('hosts')">
              {{ $t('hosts') }}
            </v-btn>
          </div>
          <div class="flex-grow-1">
            <v-btn small block color="#7cb5ec" class="text-none" @click="navigate('devices')">
              {{ $t('devices') }}
            </v-btn>
          </div>
        </div>
      </div>
      <v-divider />
      <div class="pa-2 pt-4">
        <div class="d-flex justify-space-around text-center mb-2">
          <div class="flex-grow-1">
            <div class="body-2 black--text mb-1">{{ $t('total_sessions') }}</div>
            <div class="text-h6 font-weight-bold">{{ sessions.totalSessions ?? '-' }}</div>
          </div>
          <div class="flex-grow-1">
            <div class="body-2 black--text mb-1">{{ $t('scanned_sessions') }}</div>
            <div class="text-h6 font-weight-bold">{{ sessions.scannedSessions ?? '-' }}</div>
          </div>
          <div class="flex-grow-1">
            <div class="body-2 black--text mb-1">{{ $t('bypassed_sessions') }}</div>
            <div class="text-h6 font-weight-bold">{{ sessions.bypassedSessions ?? '-' }}</div>
          </div>
        </div>
        <div class="d-flex justify-center pr-4 pl-4 pb-2">
          <v-btn small block color="#7cb5ec" class="text-none" @click="navigate('sessions')">
            {{ $t('sessions') }}
          </v-btn>
        </div>
      </div>
    </div>
  </u-widget>
</template>

<script>
  import widgetsMixin from './widgetsMixin'
  import { rpcCall } from '@/util/rpcHelpers'

  export default {
    mixins: [widgetsMixin],

    data: () => ({
      fetching: false,
      stats: {},
      sessions: {},
    }),

    methods: {
      async loadData() {
        this.fetching = true
        this.stats = this.$store.state.config.metricsAndStats?.systemStats || {}
        await this.loadSessions()
        this.fetching = false
      },

      async loadSessions() {
        const result = await rpcCall(window.rpc?.sessionMonitor?.getSessionStats, [], { fallback: null })
        this.sessions = result || {}
      },

      navigate(hash) {
        window.parent.location.href = `#${hash}`
      },
    },
  }
</script>
