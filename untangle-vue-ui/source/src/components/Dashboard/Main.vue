<template>
  <div class="simple-component">
    <h1>{{ message }}</h1>
  </div>
</template>

<script>
  export default {
    data() {
      return {
        message: 'Dashobard Component',
      }
    },
  }
</script>

<style scoped>
  .simple-component {
    text-align: center;
    font-family: Arial, sans-serif;
  }
  button {
    padding: 10px 20px;
    margin-top: 20px;
    font-size: 16px;
  }
</style>
