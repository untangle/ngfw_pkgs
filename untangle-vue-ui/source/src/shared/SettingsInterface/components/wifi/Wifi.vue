<template>
  <div>
    <u-alert class="mt-4">{{ $t('wifi_info') }}</u-alert>

    <!-- show enabled/disabled option if component used in setup wizard -->
    <div class="d-flex">
      <v-switch v-if="isSetup" v-model="intf.enabled" :label="$t('interface_enabled')" class="mt-0" />
    </div>

    <v-row>
      <v-col>
        <!-- wirelessSsid -->
        <ValidationProvider v-slot="{ errors }" rules="required">
          <u-text-field v-model="intf.wirelessSsid" :label="$t('ssid')" :error-messages="errors">
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
      <v-col>
        <!-- wirelessVisibility -->
        <ValidationProvider v-slot="{ errors }" rules="required">
          <u-select v-model="intf.hidden" :label="$t('visibility')" :items="visibilityItems" :error-messages="errors">
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-select>
        </ValidationProvider>
      </v-col>
    </v-row>
    <v-row>
      <v-col>
        <!-- wirelessEncryption -->
        <ValidationProvider v-slot="{ errors }" rules="required">
          <u-select
            v-model="intf.wirelessEncryption"
            :label="$t('encryption')"
            :items="encryptionItems"
            :error-messages="errors"
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-select>
        </ValidationProvider>
      </v-col>
      <v-col v-if="intf.wirelessEncryption !== 'NONE'">
        <!-- wirelessPassword -->
        <ValidationProvider v-slot="{ errors }" rules="required|min:8">
          <u-password v-model="intf.wirelessPassword" :label="$t('password')" :errors="errors" />
        </ValidationProvider>
      </v-col>
      <v-col v-else><!-- just placeholder --></v-col>
    </v-row>
    <v-row>
      <v-col>
        <!-- wirelessMode -->
        <ValidationProvider v-slot="{ errors }" rules="required">
          <u-select v-model="intf.wirelessMode" :label="$t('mode')" :items="modeItems" :error-messages="errors">
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-select>
        </ValidationProvider>
      </v-col>
      <v-col>
        <!-- wirelessChannel -->
        <ValidationProvider v-slot="{ errors }" rules="required">
          <u-select
            v-model="intf.wirelessChannel"
            :label="$t('channel')"
            :items="channelItems"
            item-text="frequency"
            item-value="channel"
            :error-messages="errors"
          >
            <template #selection="data">
              {{ data.item.channel }} <span class="grey--text ml-1">[ {{ data.item.frequency }} ]</span>
            </template>
            <template #item="data">
              <v-list-item-content>
                <v-list-item-title>
                  {{ data.item.channel }} <span class="grey--text ml-1">[ {{ data.item.frequency }} ]</span>
                </v-list-item-title>
              </v-list-item-content>
            </template>
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-select>
        </ValidationProvider>
      </v-col>
      <v-col>
        <!-- wirelessThroughput -->
        <ValidationProvider v-slot="{ errors }" rules="required">
          <u-select
            v-model="intf.wirelessThroughput"
            :label="$t('ht_mode')"
            :items="throughputItems"
            item-text="name"
            item-value="mode"
            :error-messages="errors"
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-select>
        </ValidationProvider>
      </v-col>
    </v-row>
  </div>
</template>
<script>
  export default {
    inject: ['$intf', '$status'],
    props: {
      /**
       * flag telling if the component is used in setup wizard
       */
      isSetup: { type: Boolean, default: false },
    },
    data() {
      return {
        channelItems: [], // async loaded
        throughputItems: [], // async loaded
      }
    },
    computed: {
      intf: ({ $intf }) => $intf(),
      status: ({ $status }) => $status(),

      encryptionItems() {
        return [
          { text: this.$t('none'), value: 'NONE' },
          { text: this.$t('wpa1'), value: 'WPA1' },
          { text: this.$t('wpa12'), value: 'WPA12' },
          { text: this.$t('wpa2'), value: 'WPA2' },
        ]
      },
      modeItems() {
        return [
          { text: this.$t('access_point'), value: 'AP' },
          { text: this.$t('client'), value: 'CLIENT' },
        ]
      },
      visibilityItems() {
        return [
          { text: this.$t('advertise_ssid_publicly'), value: false },
          { text: this.$t('hide_ssid'), value: true },
        ]
      },
    },
    async created() {
      await this.$emit('get-wifi-channels', this.intf.device, response => {
        // returns an array of objects like { 'frequency': '2.412 GHz', 'channel': 1 }
        this.channelItems = response || []
      })

      await this.$emit('get-wifi-mode-list', this.intf.device, response => {
        // returns an array of objects like { 'name': 'HT40', 'mode': 'HT40' }
        this.throughputItems = response || []
      })
    },
  }
</script>
