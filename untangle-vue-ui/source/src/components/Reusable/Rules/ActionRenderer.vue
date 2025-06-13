<template>
  <span>
    <v-icon small class="mr-1" :color="action.iconColor || ''">{{ action.icon }}</v-icon>
    <span v-html="action.text" />
  </span>
</template>
<script>
  import Vue from 'vue'
  export default Vue.extend({
    computed: {
      action: ({ params }) => params.value,
    },
  })
</script>
