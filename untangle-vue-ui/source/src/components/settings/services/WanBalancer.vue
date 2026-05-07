<template>
  <v-container fluid :class="`shared-cmp d-flex flex-column flex-grow-1 pa-0`">
    <no-license v-if="!isLicensed && isInstalled" class="mt-2">
      {{ $t('not_licensed_service', [$t('wan_balancer')]) }}
      <template #actions>
        <u-btn class="ml-4" to="/settings/system/about">{{ $t('view_system_license') }}</u-btn>
        <u-btn class="ml-4" :href="manageLicenseUri" target="_blank">
          {{ $t('manage_licenses') }}
          <v-icon right> mdi-open-in-new </v-icon>
        </u-btn>
      </template>
    </no-license>
    <wan-balancer
      v-if="settings"
      :settings="settings"
      :app-data="consolidatedAppData"
      :disabled="!isLicensed && isInstalled"
      :is-installed="isInstalled"
      :metrics-data="formattedMetrics"
      :reports="appReports"
      :traffic-allocation="trafficAllocation"
      :interface-weight-list="interfaceWeightList"
      @toggle-state="toggleAppState"
    >
      <template #actions="{ newSettings, isDirty }">
        <div v-if="isInstalled" class="d-flex flex-wrap align-center" style="gap: 8px">
          <div style="min-width: 180px">
            <u-app-status-remove class="mt-0" :app-name="$t('wan_balancer')" @remove="onRemoveService" />
          </div>
          <v-divider vertical class="mx-4" />
          <u-btn class="mr-2" @click="onRefreshData">
            {{ $vuntangle.$t('refresh') }}
          </u-btn>
          <u-btn :disabled="!isDirty" @click="onSave(newSettings)">
            {{ $vuntangle.$t('save') }}
          </u-btn>
        </div>
        <div v-else style="min-width: 180px">
          <u-app-install @install="onInstallService" />
        </div>
      </template>
    </wan-balancer>
  </v-container>
</template>

<script>
  import { WanBalancer, NoLicense, UAppStatusRemove, UAppInstall } from 'vuntangle'
  import serviceMixin from './serviceMixin'

  export default {
    components: {
      WanBalancer,
      NoLicense,
      UAppStatusRemove,
      UAppInstall,
    },
    mixins: [serviceMixin],

    provide() {
      return {
        $remoteData: () => ({
          wanInterfaces: [
            { value: 0, text: this.$t('balance') },
            ...this.interfaceWeightList.map(i => ({ value: i.interfaceId, text: i.name })),
          ],
        }),
        $features: {},
        $applications: null,
        $readOnly: false,
      }
    },

    data() {
      return {
        serviceName: 'wan-balancer',
        licenseNodeName: 'wan-balancer',
        displayNameFallback: 'WAN Balancer',
      }
    },

    computed: {
      interfaceWeightList() {
        return this.$store.getters['config/interfaces']
          .filter(i => i.wan && i.configType === 'ADDRESSED')
          .map(i => ({ interfaceId: i.interfaceId, name: i.name }))
      },

      interfaceWeightData() {
        const weights = this.settings?.weights || []
        const list = this.interfaceWeightList
        const total = list.reduce((sum, i) => sum + (weights[i.interfaceId - 1] ?? 0), 0)
        const intfCount = list.length
        return list.map(i => ({
          interfaceId: i.interfaceId,
          name: i.name,
          weight: weights[i.interfaceId - 1] ?? 0,
          description: this.getDescription(intfCount, total, weights[i.interfaceId - 1] ?? 0),
        }))
      },

      trafficAllocation() {
        return this.interfaceWeightData.map(i => ({
          interfaceName: i.name,
          percentage: parseFloat(i.description),
        }))
      },
    },

    created() {
      this.fetchSettings(false)
    },

    methods: {
      async fetchSettings(refetch) {
        await this.$store.dispatch('config/getNetworkSettings', refetch)
      },

      getDescription(intfCount, total, weight) {
        return total === 0 ? Math.round((1 / intfCount) * 1000) / 10 : Math.round((weight / total) * 1000) / 10
      },

      setWeights(newSettings) {
        const weights = new Array(255).fill(0)
        this.interfaceWeightList.forEach(i => {
          weights[i.interfaceId - 1] = newSettings.weights?.[i.interfaceId - 1] ?? 0
        })
        return { ...newSettings, weights }
      },

      async onSave(newSettings) {
        await this.saveSettings(this.setWeights(newSettings))
      },

      onRefreshData() {
        this.$store.dispatch('config/getNetworkSettings', true)
        this.refreshData()
      },
    },
  }
</script>
