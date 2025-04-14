<!--
  Component shown as a tab for non VPN interfaces,
  used to edit VRRP interface settings as below:
  - vrrpEnabled
  - vrrpId
  - vrrpPriority
  - vrrpV4Aliases
-->
<template>
  <div>
    <!-- vrrpEnabled -->
    <v-switch v-model="intf.vrrpEnabled" :label="$t('vrrp_enabled')" class="ma-0" />

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
          :rules="intf.vrrpEnabled ? `required|numeric|integer|min_value:1|max_value:254` : ''"
        >
          <u-text-field
            v-model.number="intf.vrrpPriority"
            type="number"
            :disabled="!intf.vrrpEnabled"
            :label="$t('vrrp_priority')"
            :error-messages="errors"
            :hide-details="false"
            :hint="$t('vrrp_priority_hint')"
            persistent-hint
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
    </v-row>

    <!-- vrrptrack -->
    <v-card v-if="features.interfaceTracking" flat :disabled="!intf.vrrpEnabled" color="transparent">
      <vrrp-tracking alias-key="vrrptrack" />
    </v-card>

    <!-- vrrpV4Aliases -->
    <v-card flat :disabled="!intf.vrrpEnabled" color="transparent">
      <ipv-4-aliases alias-key="vrrpV4Aliases" />
    </v-card>
  </div>
</template>
<script>
  import { VSwitch, VRow, VCol, VCard } from 'vuetify/lib'
  import Ipv4Aliases from '../ipv4/Ipv4Aliases.vue'
  import VrrpTracking from './VrrpTracking.vue'

  export default {
    components: {
      VSwitch,
      VRow,
      VCol,
      VCard,
      Ipv4Aliases,
      VrrpTracking,
    },
    inject: ['$intf', '$features'],

    computed: {
      intf: ({ $intf }) => $intf(),
      features: ({ $features }) => $features(),
    },
  }
</script>
