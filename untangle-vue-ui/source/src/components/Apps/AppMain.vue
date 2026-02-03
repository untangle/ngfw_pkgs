<template>
  <component :is="appComponent" />
</template>

<script>
  export default {
    name: 'AppMain',
    computed: {
      appComponent() {
        const appName = this.$route.params.appName
        // Converts kabab-case to PascalCase
        const componentName = appName
          .split('-')
          .map(word => word.charAt(0).toUpperCase() + word.slice(1))
          .join('')
        return () => import(`./${componentName}/${componentName}.vue`)
      },
    },
  }
</script>
