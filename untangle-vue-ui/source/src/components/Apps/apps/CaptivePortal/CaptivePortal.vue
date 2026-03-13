<template>
  <div>
    <h1>{{ appDisplayName }}</h1>
  </div>
</template>

<script>
  export default {
    name: 'CaptivePortal',

    props: {
      appData: { type: Object, default: null },
    },

    computed: {
      /**
       * Application display name, derived from appData properties or defaults to a static string
       * @param param0 - Destructured appData from component's props
       * @returns {string} Display name for the application
       */
      appDisplayName: ({ appData }) => appData?.appProperties?.displayName || 'Captive Portal',
    },
  }
</script>
