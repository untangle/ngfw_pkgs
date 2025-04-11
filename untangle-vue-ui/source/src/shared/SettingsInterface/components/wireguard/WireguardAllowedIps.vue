<template>
  <div>
    <p class="font-weight-bold mt-6 mb-2">{{ $t('allowed_ips') }}</p>

    <v-chip v-for="(item, idx) in ips" :key="idx" close small class="mr-2 mb-2" @click:close="onRemoveIp(idx)">
      {{ item.address }}{{ item.prefix || item.prefix === 0 ? `/${item.prefix}` : '' }}
    </v-chip>

    <v-chip v-if="!adding" small color="primary" class="mr-2 mb-2" @click="adding = true">
      {{ $t('add_ip') }}
    </v-chip>

    <ValidationObserver v-slot="{ passes }" tag="div">
      <v-row v-if="adding" no-gutters align="center" class="mt-2">
        <v-col class="grow">
          <!-- address -->
          <ValidationProvider v-slot="{ errors }" :rules="ipAddressRules">
            <u-text-field v-model="ip.address" :label="$t('address')" class="mr-2" :error-messages="errors">
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
        <v-col class="grow">
          <!-- prefix -->
          <ValidationProvider v-slot="{ errors }" rules="required">
            <ipv-4-prefix-autocomplete v-model="ip.prefix" :errors="errors" />
          </ValidationProvider>
        </v-col>
        <v-col class="shrink">
          <u-btn icon :small="false" :min-width="null" class="primary mx-4" @click="passes(onAddIp)">
            <v-icon color="white">mdi-check</v-icon>
          </u-btn>
        </v-col>
        <v-col class="shrink">
          <u-btn icon :small="false" :min-width="null" @click="adding = false"><v-icon>mdi-close</v-icon></u-btn>
        </v-col>
      </v-row>
    </ValidationObserver>
  </div>
</template>
<script>
  import defaults from '../../defaults'
  import i18n from '../../../../plugins/vue-i18n'
  import Ipv4PrefixAutocomplete from '../../../../components/Ipv4PrefixAutocomplete'

  export default {
    components: {
      Ipv4PrefixAutocomplete,
    },
    inject: ['$intf', '$status'],
    props: {
      ips: { type: Array, default: () => [] },
    },
    data() {
      return {
        list: this.$intf().wireguardPeers[0].allowedIps,
        // model for new v4 alias
        ip: { ...defaults.wg_ip_config },
        adding: false, // boolean telling to show the add fields
      }
    },
    computed: {
      listIps: ({ list }) => list.map(ipAddr => ipAddr.address),
      ipAddressRules() {
        return {
          required: true,
          ip: true,
          unique_insensitive: {
            list: this.listIps,
            message: i18n.t('geoip_network_duplicate', [this.ip.address]),
          },
        }
      },
    },
    watch: {
      adding(value) {
        if (!value) {
          // reset
          this.ip = { ...defaults.wg_ip_config }
        }
      },
      list: {
        deep: true,
        handler(newList) {
          this.$emit('update:ips', newList)
        },
      },
      ips: {
        deep: true,
        handler(newIps) {
          this.list = newIps
        },
      },
    },
    methods: {
      onAddIp() {
        this.list.push(this.ip)
        this.adding = false
      },

      onRemoveIp(index) {
        this.list.splice(index, 1)
      },
    },
  }
</script>
