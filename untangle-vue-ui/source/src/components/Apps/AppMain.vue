<template>
  <div>
    <p>Policy ID: {{ $route.params.policyId }}</p>
    <p>App Name: {{ $route.params.appName }}</p>
  </div>
</template>
<script>
  export default {
    name: 'AppMain',
  }
</script>
