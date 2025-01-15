<template>
  <v-app>
    <v-main>
      <router-view class="d-flex flex-column fill-height" />
    </v-main>

    <v-overlay v-model="$store.state.fetching">
      <v-progress-circular indeterminate size="32" color="aristaBlue" />
    </v-overlay>

    <u-framework-dialog />
    <u-framework-confirm />
    <u-framework-toast />
  </v-app>
</template>
<script>
  export default {}
</script>
<!-- <template>
  <v-app>
    <v-main>
      <router-view />
    </v-main>
  </v-app>
</template> -->
