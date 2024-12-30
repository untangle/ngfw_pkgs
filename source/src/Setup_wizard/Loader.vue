<template>
  <div v-if="show" class="loader-overlay">
    <div class="loader"></div>
    <p>{{ message }}</p>
  </div>
</template>

<script>
  export default {
    props: {
      show: {
        type: Boolean,
        required: true,
      },
      message: {
        type: String,
        default: 'Loading...',
      },
    },
  }
</script>

<style scoped>
  .loader-overlay {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    z-index: 9999;
    color: white;
    font-size: 16px;
  }

  .loader {
    border: 4px solid rgba(255, 255, 255, 0.3);
    border-top: 4px solid white;
    border-radius: 50%;
    width: 40px;
    height: 40px;
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    0% {
      transform: rotate(0deg);
    }
    100% {
      transform: rotate(360deg);
    }
  }
</style>
