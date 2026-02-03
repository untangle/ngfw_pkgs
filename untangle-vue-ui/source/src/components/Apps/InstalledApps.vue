<template>
  <div class="d-flex flex-row flex-wrap" style="gap: 14px">
    <app-card v-for="(app, key) in installedApps" :key="key" :app="app" />
  </div>
</template>

<script>
  import AppCard from './AppCard.vue'

  export default {
    name: 'InstalledApps',
    components: {
      AppCard,
    },
    props: {
      installedApps: {
        type: Array,
        required: true,
      },
    },
  }
</script>
