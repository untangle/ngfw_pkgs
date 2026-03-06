<template>
  <v-container fluid :class="`shared-cmp d-flex flex-column flex-grow-1 pa-0`">
    <no-license v-if="isLicensed === false" class="mt-2">
      {{ $t('not_licensed_service', [$t('branding_manager')]) }}
      <template #actions>
        <u-btn class="ml-4" to="/settings/system/about">{{ $t('view_system_license') }}</u-btn>
        <u-btn class="ml-4" :href="manageLicenseUri" target="_blank">
          {{ $t('manage_licenses') }}
          <v-icon right> mdi-open-in-new </v-icon>
        </u-btn>
      </template>
    </no-license>

    <branding-manager :settings="settings" :disabled="!isLicensed" />
  </v-container>
</template>

<script>
  import { BrandingManager, NoLicense } from 'vuntangle'
  import serviceMixin from './serviceMixin'

  export default {
    components: {
      BrandingManager,
      NoLicense,
    },
    mixins: [serviceMixin],

    data() {
      return {
        licenseNodeName: 'branding-manager',
      }
    },

    computed: {
      settings: ({ $store }) => $store.getters['apps/getSettings']('branding-manager')?.settings,
    },

    created() {
      this.$store.dispatch('apps/loadAppData', this.licenseNodeName)
    },
  }
</script>
