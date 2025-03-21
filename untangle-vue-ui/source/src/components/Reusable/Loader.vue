<template>
  <div v-if="loading" class="loading-overlay">
    <div class="loading-message">
      <p>{{ message }}</p>
      <div class="spinner"></div>
    </div>
  </div>
</template>

<script>
  export default {
    props: {
      loading: {
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
  .loading-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: rgba(0, 0, 0, 0.5);
    display: flex;
    justify-content: center;
    align-items: center;
    z-index: 1000;
  }

  .loading-message {
    background-color: white;
    padding: 20px;
    border-radius: 8px;
    text-align: center;
    max-width: 300px;
    word-wrap: break-word;
  }

  .spinner {
    border: 4px solid rgba(255, 255, 255, 0.3);
    border-top: 4px solid #3498db;
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
