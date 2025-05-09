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

    <!-- vrrpV4Aliases -->
    <v-card flat :disabled="!intf.vrrpEnabled" color="transparent">
      <vrrp-aliases alias-key="vrrpV4Aliases" />
    </v-card>
  </div>
</template>
<script>
  import { VSwitch, VRow, VCol, VCard } from 'vuetify/lib'
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
    },
  }
</script>
