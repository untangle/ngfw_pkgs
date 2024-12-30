<template>
  <ServerSettings v-if="showServerSettings" :setup-rpc="setupRpc" :admin-rpc="adminRpc" />
  <div v-else class="license">
    <div class="content-container">
      <h2>License</h2>
      <p class="description">
        To continue installing and using this software, you must agree to the terms and conditions of the software
        license agreement. Please review the whole license agreement by navigating to the provided website link and
        scrolling through to the end of the agreement.
      </p>

      <p class="license-link">
        The license is available at
        <a id="licenseUrl" :href="remoteEulaSrc" target="_blank">
          {{ remoteEulaSrc }}
        </a>
      </p>

      <p class="after-setup">After completing the setup, legal links can also be viewed from the About page.</p>

      <div class="button-container">
        <button class="disagree-button" @click="onDisagree">Disagree</button>
        <button class="agree-button" @click="onContinue">Agree</button>
      </div>
    </div>
  </div>
</template>

<script>
  import ServerSettings from '@/Setup_wizard/step/ServerSettings.vue'

  export default {
    components: {
      ServerSettings,
    },
    props: {
      setupRpc: {
        type: Object,
        required: true,
      },
      adminRpc: {
        type: Object,
        required: true,
      },
    },
    data() {
      return {
        remoteEulaSrc: '',
        remoteImage: '',
        timer: null,
        showServerSettings: false,
      }
    },
    mounted() {
      this.afterRender()
      console.log('setupRpc', this.setupRpc)
      console.log('adminRpc', this.adminRpc)
    },
    methods: {
      afterRender() {
        // Retrieve license URLs from the RPC configuration
        this.remoteEulaSrc = this.setupRpc.licenseAgreementUrl
        this.remoteImage = this.setupRpc.licenseTestUrl

        const hyperlink = document.getElementById('licenseUrl')
        hyperlink.href = this.remoteEulaSrc
        hyperlink.innerText = this.remoteEulaSrc

        const img = new Image(0, 0)
        img.onload = this.clearTimer
        img.onerror = img.onabort = this.handleFail

        img.src = this.remoteImage
        this.timer = setTimeout(() => this.handleFail(), 1000)
      },
      clearTimer() {
        if (this.timer) {
          clearTimeout(this.timer)
          this.timer = null
        }
      },
      handleFail() {
        console.error('Failed to load license resources.')
        this.clearTimer()
      },
      onContinue() {
        // this.$emit('next')
        this.showServerSettings = true
      },
      onDisagree() {
        window.location.reload()
      },
    },
  }
</script>

<style scoped>
  .license {
    display: flex;
    justify-content: center;
    align-items: center;
    padding: 20px;
    text-align: center;
    font-family: Arial, sans-serif;
    border: 2px solid #ccc; /* Add border */
    border-radius: 8px; /* Optional: rounded corners */
    margin: 20px; /* Optional: spacing around the div */
  }

  .content-container {
    max-width: 600px;
  }

  .description {
    margin-bottom: 10px;
    word-wrap: break-word;
  }

  .license-link {
    margin-top: 10px;
    word-wrap: break-word;
  }

  .after-setup {
    margin-top: 10px;
    font-weight: bold;
  }

  .button-container {
    display: flex;
    justify-content: center;
    margin-top: 15px;
  }

  .disagree-button,
  .agree-button {
    margin: 0 10px;
    padding: 10px 20px;
    border: none;
    cursor: pointer;
    font-size: 16px;
  }

  .disagree-button {
    background-color: #f44336;
    color: white;
  }

  .agree-button {
    background-color: #4caf50;
    color: white;
  }
</style>
