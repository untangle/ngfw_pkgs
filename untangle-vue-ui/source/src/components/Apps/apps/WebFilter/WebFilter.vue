<template>
  <div>
    <h1>{{ appDisplayName }}</h1>
  </div>
</template>

<script>
  export default {
    name: 'WebFilter',

    props: {
      appData: {
        type: Object,
        default: null,
      },
    },

    computed: {
      appDisplayName() {
        return this.appData?.appProperties?.displayName || 'Web Filter'
      },
    },
  }
</script>
