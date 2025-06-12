<template>
  <div>
    <!-- show enabled/disabled option if component used in setup wizard -->
    <div class="d-flex">
      <v-switch v-if="isSetup" v-model="intf.enabled" :label="$t('interface_enabled')" class="mt-0" />
    </div>

    <v-row>
      <v-col>
        <!-- wirelessSsid -->
        <ValidationProvider v-slot="{ errors }" rules="required|max:30|ssid_mask">
          <u-text-field v-model="intf.wirelessSsid" :label="$t('ssid')" :error-messages="errors">
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
      <v-col>
        <!-- wirelessMode -->
        <ValidationProvider v-slot="{ errors }" rules="required">
          <u-select v-model="intf.wirelessMode" :label="$t('mode')" :items="modeItems" :error-messages="errors">
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
      <v-col>
        <!-- wirelessPassword -->
        <ValidationProvider v-slot="{ errors }" rules="required|min:8|max:63|password_mask">
          <u-password
            v-model="intf.wirelessPassword"
            :label="$t('password')"
            :disabled="intf.wirelessEncryption === 'NONE' || intf.wirelessEncryption == undefined"
            :errors="intf.wirelessEncryption === 'NONE' ? [] : errors"
          />
        </ValidationProvider>
      </v-col>
    </v-row>
    <v-row>
      <v-col>
        <!-- wirelessLoglevel -->
        <ValidationProvider v-slot="{ errors }" rules="required">
          <u-select
            v-model="intf.wirelessLogLevel"
            :label="$t('loglevel')"
            :items="loglevelItems"
            :error-messages="errors"
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-select>
        </ValidationProvider>
      </v-col>
      <v-col v-if="intf.wirelessMode === 'AP'">
        <!-- wirelessVisibility -->
        <ValidationProvider v-slot="{ errors }" rules="required">
          <u-select
            v-model="intf.wirelessVisibility"
            :label="$t('visibility')"
            :items="visibilityItems"
            :error-messages="errors"
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-select>
        </ValidationProvider>
      </v-col>
      <v-col v-else><!-- Placeholder --></v-col>
    </v-row>
    <v-row v-if="intf.wirelessMode === 'AP'">
      <v-col>
        <!-- wirelessCountryCode -->
        <ValidationProvider v-slot="{ errors }" rules="required">
          <u-select
            v-model="intf.wirelessCountryCode"
            :label="$t('regularatory_country')"
            :items="countryCodeItems"
            :error-messages="errors"
            @change="onCountryChange"
          >
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
    </v-row>
    <u-alert v-if="!wirelessRegulatoryCompliant && intf.wirelessMode === 'AP'" class="mt-4">{{
      $t('wireless_adapter_driver_support')
    }}</u-alert>
  </div>
</template>
<script>
  import { extend } from 'vee-validate'
  import { countryMap } from '@/constants/index'

  export default {
    inject: ['$intf', '$status'],
    props: {
      /**
       * flag telling if the component is used in setup wizard
       */
      isSetup: { type: Boolean, default: false },
    },
    data() {
      return {}
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
          { text: this.$t('advertise_ssid_publicly'), value: 0 },
          { text: this.$t('hide_ssid'), value: 1 },
        ]
      },
      loglevelItems() {
        return [
          { text: this.$t('debug'), value: 1 },
          { text: this.$t('info'), value: 2 },
          { text: this.$t('warn'), value: 4 },
        ]
      },

      channelItems: {
        get() {
          let wantCountry = this.intf.wirelessCountryCode
          if (wantCountry === '') {
            wantCountry = window.rpc.networkManager.getWirelessRegulatoryCountryCode(this.intf.systemDev)
          }
          return (
            window.rpc.networkManager.getWirelessChannels(this.intf.systemDev, wantCountry) || [
              { frequency: this.$t('no_channel_match'), channel: -1 },
            ]
          )
        },
        set() {},
      },

      countryCodeItems() {
        console.log('countryCodeItems')
        const wirelessCountryList = []
        const countryCodes = window.rpc.networkManager.getWirelessValidRegulatoryCountryCodes(this.intf.systemDev)

        for (const country in countryMap) {
          if (Array.isArray(countryCodes) && countryCodes.includes(country)) {
            wirelessCountryList.push({ text: countryMap[country], value: country })
          }
        }
        return wirelessCountryList
      },

      wirelessRegulatoryCompliant: ({ intf }) =>
        window.rpc.networkManager.isWirelessRegulatoryCompliant(intf.systemDev),
    },

    watch: {
      channelItems: {
        handler(newChannels) {
          const currentChannel = this.intf.wirelessChannel
          const match = newChannels.some(ch => ch.channel === currentChannel)

          if (!match) {
            this.intf.wirelessChannel = -1
          }
        },
        immediate: true,
      },
    },

    created() {
      extend('ssid_mask', {
        validate: value => /^[a-zA-Z0-9\-_= ]+$/.test(value),
        message: this.$t('ssid_regex_validation_message'),
      })
      extend('password_mask', {
        validate: value => /^[a-zA-Z0-9~@#%_=,!?\-()[\]\\^$+*.|]+$/.test(value),
        message: this.$t('wireless_password_regex_validation_message'),
      })

      // Set default encryption if undefined
      if (!this.intf.wirelessEncryption) {
        this.intf.wirelessEncryption = 'NONE'
      }

      // Set wirelessCountryCode if undefined
      if (!this.intf.wirelessCountryCode) {
        this.intf.wirelessCountryCode = window.rpc.networkManager.getWirelessRegulatoryCountryCode(this.intf.systemDev)
      }
    },

    methods: {
      onCountryChange(newValue) {
        // Update channel items based on new value
        this.channelItems = window.rpc.networkManager.getWirelessChannels(this.intf.systemDev, newValue) || [
          { frequency: this.$t('no_channel_match'), channel: -1 },
        ]
        const currentChannel = this.intf.wirelessChannel
        const match = this.channelItems.some(ch => ch.channel === currentChannel)

        if (!match) {
          this.intf.wirelessChannel = -1
        }
      },
    },
  }
</script>
