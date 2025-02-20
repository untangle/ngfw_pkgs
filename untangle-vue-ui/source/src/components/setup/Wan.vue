<template>
  <v-card width="650" class="mx-auto mt-4" flat>
    <h2 class="d-flex font-weight-light text-center">
      {{ $t('wan') }}
      <v-spacer />
      <u-btn :min-width="null" rounded outlined @click="onRefresh">{{ $t('refresh') }}</u-btn>
    </h2>
    <p v-if="isOnline" class="text-center"><v-icon color="green">mdi-wan</v-icon> {{ $t('device_is_online') }}</p>
    <p v-else class="text-center"><v-icon color="red">mdi-wan</v-icon> {{ $t('device_is_offline') }}</p>
    <ValidationObserver v-slot="{ passes }" tag="div">
      <div v-for="(intf, i) in interfacesCopy" :key="i">
        <v-card v-if="intf.type === 'NIC' && intf.wan" outlined class="mb-4">
          <v-card-title class="d-flex pb-0 pt-2">
            {{ intf.name }}
            <span v-if="wanStatus && wanStatus[intf.device].macAddress">
              &nbsp;| {{ wanStatus[intf.device].macAddress }}
            </span>
            <v-spacer />
            <div v-if="status && wanStatus" class="caption">
              <v-icon x-small :color="wanStatus[intf.device].connected ? 'green' : 'grey'">mdi-circle</v-icon>
              <span class="ml-1 mr-2">
                {{ wanStatus[intf.device].connected ? $t('connected') : $t('not_connected') }}
              </span>
              <span>
                <v-icon small>mdi-arrow-down-bold</v-icon>
                {{ wanStatus[intf.device].rxByteRate / 1000 }} {{ $t('kbps') }}
                <v-icon small>mdi-arrow-up-bold</v-icon>
                {{ wanStatus[intf.device].txByteRate / 1000 }} {{ $t('kbps') }}
              </span>
            </div>
          </v-card-title>
          <!-- have to use `interfacesCopy[i]` for `sync` to work -->
          <ipv-4
            v-if="wanStatus"
            :intf.sync="interfacesCopy[i]"
            :status="wanStatus[intf.device]"
            is-setup
            class="pa-4"
          />
        </v-card>
      </div>
      <div class="text-center">
        <u-btn :small="false" @click="passes(onContinue)">{{ $t('continue') }}</u-btn>
      </div>
    </ValidationObserver>
  </v-card>
</template>
<script>
  import cloneDeep from 'lodash/cloneDeep'
  import api from '@/plugins/api'
  import store from '@/store'
  import Ipv4 from '@/components/settings/interface/Ipv4.vue'

  export default {
    components: { Ipv4 },
    data: () => ({
      status: null,
      interfacesCopy: null,
      loading: false,
    }),
    computed: {
      // returns all interfaces
      interfaces() {
        return store.getters['settings/interfaces']
      },

      // creates a status object for each device
      wanStatus() {
        if (!this.status) return
        const status = {}
        this.status.forEach(s => {
          status[s.device] = s
        })
        return status
      },

      // returns online status if any of the interfaces is connected
      isOnline() {
        if (!this.status) return false
        return !this.status.offline
      },
    },

    watch: {
      interfaces: {
        immediate: true,
        handler(value) {
          this.interfacesCopy = cloneDeep(value)
        },
      },
    },

    mounted() {
      // get the status for the interfaces on mount
      this.getStatus()
    },

    methods: {
      // refreshes the interfaces; TODO check how this works on real devices
      async onRefresh() {
        store.commit('SET_LOADER', true)
        await store.dispatch('settings/getInterfaces')
        this.getStatus()
        store.commit('SET_LOADER', false)
      },

      // get all interfaces status
      async getStatus() {
        const response = await api.get(`/api/status/interfaces/all`)
        if (response && Array.isArray(response)) {
          this.status = response
        }
      },

      // continue to next step after validation and interfaces settings save
      async onContinue() {
        store.commit('SET_LOADER', true)
        const response = await store.dispatch('settings/setInterfaces', this.interfacesCopy)
        // avoid next step if saving fails
        if (!response.success) {
          store.commit('SET_LOADER', false)
          return
        }
        const nextStep = await store.dispatch('setup/setStatus', 'wan')
        store.commit('SET_LOADER', false)
        if (nextStep) {
          this.$router.push(`/setup/${nextStep}`)
        }
      },
    },
  }
</script>
