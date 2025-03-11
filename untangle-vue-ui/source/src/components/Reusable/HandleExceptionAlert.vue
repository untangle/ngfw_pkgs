<!-- HandleExceptionAlert.vue -->
<template>
  <div class="alert-container">
    <div class="alert-message">
      <p v-html="alert.message"></p>
    </div>

    <!-- "Show Details" button -->
    <u-btn v-if="alert.details" class="details-button" @click="toggleDetails">
      {{ showDetails ? 'Hide details' : 'Show details' }}
    </u-btn>

    <!-- Error details (toggle visibility) -->
    <div v-if="showDetails" class="alert-details">
      <p v-html="alert.details"></p>
    </div>
  </div>
</template>

<script>
  export default {
    props: {
      alert: {
        type: Object,
        required: true,
      },
    },
    data() {
      return {
        showDetails: false,
      }
    },
    methods: {
      toggleDetails() {
        this.showDetails = !this.showDetails
      },
      onClose() {
        this.$emit('close') // Notify parent to close dialog
      },
    },
  }
</script>

<style scoped>
  .alert-container {
    text-align: left;
    padding: 10px;
    font-family: Arial, sans-serif;
  }

  .alert-message {
    font-size: 14px;
    margin-bottom: 10px;
  }

  .details-button {
    background-color: #f1f1f1;
    border: 1px solid #ccc;
    padding: 5px;
    cursor: pointer;
    font-size: 12px;
  }

  .alert-details {
    margin-top: 10px;
    background-color: #fafafa;
    border: 1px solid #ddd;
    padding: 10px;
    font-size: 12px;
    max-height: 200px;
    overflow-y: auto;
  }

  .alert-actions {
    margin-top: 10px;
    text-align: right;
  }

  .ok-button {
    background-color: #ccc;
    border: 1px solid #999;
    padding: 5px 10px;
    cursor: pointer;
  }
</style>
