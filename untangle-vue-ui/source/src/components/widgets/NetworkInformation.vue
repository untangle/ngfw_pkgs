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
        <div class="d-grid text-center" style="grid-template-columns: repeat(3, 1fr); display: grid">
          <div>
            <div class="body-2 black--text mb-1">{{ $t('currently_active') }}</div>
            <div class="text-h6 font-weight-bold">{{ stats.activeHosts ?? '-' }}</div>
          </div>
          <div>
            <div class="body-2 black--text mb-1">{{ $t('maximum_active') }}</div>
            <div class="text-h6 font-weight-bold">{{ stats.maxActiveHosts ?? '-' }}</div>
          </div>
          <div>
            <div class="body-2 black--text mb-1">{{ $t('known_devices') }}</div>
            <div class="text-h6 font-weight-bold">{{ stats.knownDevices ?? '-' }}</div>
          </div>
        </div>
        <div class="d-flex px-4 pt-2 pb-1" style="gap: 8px">
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
        <div class="d-flex justify-space-around text-center mb-2" style="gap: 8px">
          <div class="flex-grow-1">
            <div class="body-2 black--text mb-1 d-flex align-end justify-center ml-4" style="min-height: 2.5em">
              {{ $t('total_sessions') }}
            </div>
            <div class="text-h6 font-weight-bold ml-8">{{ sessions.totalSessions ?? '-' }}</div>
          </div>
          <div class="flex-grow-1">
            <div class="body-2 black--text mb-1 d-flex align-end justify-center ml-6" style="min-height: 2.5em">
              {{ $t('scanned_sessions') }}
            </div>
            <div class="text-h6 font-weight-bold ml-6">{{ sessions.scannedSessions ?? '-' }}</div>
          </div>
          <div class="flex-grow-1">
            <div class="body-2 black--text mb-1 d-flex align-end justify-center" style="min-height: 2.5em">
              {{ $t('bypassed_sessions') }}
            </div>
            <div class="text-h6 font-weight-bold">{{ sessions.bypassedSessions ?? '-' }}</div>
          </div>
        </div>
        <div class="d-flex justify-center px-4">
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
