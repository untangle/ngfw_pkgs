<template>
  <v-container>
    <u-section :title="$t('about')">
      <v-list dense class="py-0">
        <v-list-item v-for="data in serverData" :key="data.name" class="pa-0">
          <v-list-item-content>
            <v-list-item-title>{{ $vuntangle.$t(data.name) }}</v-list-item-title>
            <v-list-item-subtitle v-text="data.value" />
          </v-list-item-content>
        </v-list-item>
        <v-list-item v-if="legalUrl" class="pa-0">
          <v-list-item-content>
            <v-list-item-title>{{ $t('license_agreement') }}</v-list-item-title>
            <a :href="legalUrl" target="_blank">{{ legalUrl }}</a>
          </v-list-item-content>
        </v-list-item>
      </v-list>
    </u-section>

    <u-section :title="$t('license')">
      <v-simple-table dense>
        <template #default>
          <thead>
            <tr>
              <th class="text-left">{{ $t('name') }}</th>
              <th class="text-left" style="width: 150px">{{ $t('seats') }}</th>
              <th class="text-left" style="width: 150px">{{ $t('start') }}</th>
              <th class="text-left" style="width: 150px">{{ $t('end') }}</th>
              <th class="text-left" style="width: 150px">{{ $t('valid') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="lic in licenses" :key="lic.key">
              <td>
                <strong>{{ lic.displayName || lic.name }}</strong>
              </td>
              <td>{{ lic.seats }}</td>
              <td>{{ $vuntangle.dates.formatDateFromApi(lic.start, false) }}</td>
              <td>{{ $vuntangle.dates.formatDateFromApi(lic.end, false) }}</td>
              <td>{{ lic.valid }}</td>
            </tr>
          </tbody>
        </template>
      </v-simple-table>
      <template #actions>
        <u-btn class="mr-2">{{ $t('refresh_licenses') }}</u-btn>
      </template>
    </u-section>
  </v-container>
</template>
<script>
  export default {
    data() {
      return {
        serverData: [],
        licenses: [],
        licenseFetching: false,
        legalUrl: undefined,
      }
    },

    mounted() {
      this.getServerData()
      this.getLicenseData()
      this.getLegalUrl()
    },

    methods: {
      getServerData() {
        // console.log(window.rpcvue)
        this.serverData = [
          { name: 'uid', value: window.rpc.serverUID },
          {
            name: 'build',
            value: window.rpc.fullVersionAndRevision,
          },
          {
            name: 'kernel',
            value: window.rpc.adminManager.getKernelVersion(),
          },
          {
            name: 'region',
            value: window.rpc.regionName,
          },
          {
            name: 'history',
            value: window.rpc.adminManager.getModificationState(),
          },
          {
            name: 'Reboots',
            value: window.rpc.adminManager.getRebootCount(),
          },
          {
            name: 'Current active device count',
            value: window.rpc.hostTable.getCurrentActiveSize(),
          },
          {
            name: 'Highest active device count since reboot',
            value: window.rpc.hostTable.getMaxActiveSize(),
          },
        ]
      },

      async getLicenseData() {
        console.log('window.rpc', window.rpc)
        if (!window.rpc.licenseManager) {
          window.rpc.licenseManager = window.rpc.UvmContext.licenseManager()
        }
        this.licenseFetching = true
        // commented out for now, it blocks ui
        // await window.rpc.licenseManager.reloadLicenses(true)
        const res = await window.rpc.licenseManager.getLicenses()
        this.licenseFetching = false
        this.licenses = res.list
      },

      getLegalUrl() {
        this.legalUrl = window.rpc.UvmContext.getLegalUrl()
      },
    },
  }
</script>
