<template>
  <div>
    <!-- vrrpEnabled -->
    <v-row align="center" class="my-2">
      <v-col cols="auto">
        <v-switch v-model="intf.vrrpEnabled" :label="$t('vrrp_enabled')" class="ma-0" />
      </v-col>
      <v-spacer />

      <!-- VRRP Master Status -->
      <v-col cols="auto" class="d-flex align-center">
        <span class="mr-1">{{ $t('Is VRRP Master') }}</span>
        <v-icon :color="vrrpmaster ? 'green' : 'grey'">mdi-circle</v-icon>
      </v-col>
    </v-row>

    <v-row>
      <v-col cols="4">
        <!-- vrrpId -->
        <ValidationProvider
          v-slot="{ errors }"
          :rules="intf.vrrpEnabled ? `required|numeric|integer|min_value:1|max_value:255` : ''"
        >
          <u-text-field
            v-model.number="intf.vrrpId"
            type="number"
            :disabled="!intf.vrrpEnabled"
            :label="$t('vrrp_id')"
            :error-messages="errors"
            :hide-details="false"
            :hint="$t('vrrp_id_hint')"
            persistent-hint
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>

      <v-col cols="4">
        <!-- vrrpPriority -->
        <ValidationProvider
          v-slot="{ errors }"
          :rules="intf.vrrpEnabled ? `required|numeric|integer|min_value:1|max_value:255` : ''"
          :hint="$t('VRRP Priority must be a valid integer between 1 and 255.')"
        >
          <u-text-field
            v-model.number="intf.vrrpPriority"
            type="number"
            :disabled="!intf.vrrpEnabled"
            :label="$t('vrrp_priority')"
            :error-messages="errors"
            :hide-details="false"
            :hint="$t('VRRP ID must be a valid integer between 1 and 255.')"
            persistent-hint
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
    </v-row>

    <!-- vrrpAliases -->
    <v-card flat :disabled="!intf.vrrpEnabled" color="transparent">
      <vrrp-aliases alias-key="vrrpAliases" />
    </v-card>
  </div>
</template>
<script>
  import { VSwitch, VRow, VCol, VCard } from 'vuetify/lib'
  // import { method } from 'lodash'
  import Util from '../../../../../../util/setupUtil'
  import VrrpAliases from './VrrpAliases.vue'

  export default {
    components: {
      VSwitch,
      VRow,
      VCol,
      VCard,
      VrrpAliases,
    },
    inject: ['$intf', '$status'],
    data() {
      return {
        vrrpmaster: false,
      }
    },
    // props: {
    //   vrrpmaster: {
    //     type: Boolean,
    //     default: false,
    //   },
    // },

    computed: {
      intf: ({ $intf }) => $intf(),
      status: ({ $status }) => $status(),
    },
    watch: {
      'intf.vrrpAliases'(vrrpAliases) {
        if (!vrrpAliases) {
          this.$set(this.intf, 'vrrpAliases', {
            javaClass: 'java.util.LinkedList',
            list: [],
          })
        }
      },
      'intf.vrrpEnabled': 'setVrrpmaster',
      'intf.interfacesId': 'setVrrpmaster',
    },
    mounted() {
      this.setVrrpmaster()
    },
    methods: {
      async setVrrpmaster() {
        if (this.intf.vrrpEnabled && this.intf.interfaceId > 0) {
          try {
            this.vrrpmaster = await window.rpc.networkManager.isVrrpMaster(this.intf.interfaceId)
          } catch (ex) {
            Util.handleException(ex)
          }
        }
      },
    },
  }
</script>
