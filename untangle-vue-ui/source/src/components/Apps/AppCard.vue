<template>
  <v-card
    :elevation="hovered ? 2 : 0"
    :outlined="hovered"
    class="app-card"
    :class="{ 'from-parent': app.parentPolicy, installing: app.installing }"
    style="flex-basis: 10%"
    :disabled="!!app.parentPolicy || app.installing"
    @mouseover="hovered = true"
    @mouseleave="hovered = false"
    @click="!app.parentPolicy && !app.installing && goToApp(app)"
  >
    <v-card-text class="text-center">
      <div class="license-wrapper">
        <span v-if="app.licenseMessage" class="license">{{ app.licenseMessage }}</span>
      </div>
      <div class="icon-wrapper">
        <span v-if="app.hasPowerButton" :class="`state ${app.powerCls}`">
          <v-icon small>mdi-power</v-icon>
        </span>
        <img :src="require(`@/assets/icons/apps/${app.appName}.svg`)" width="90" height="90" alt="App icon" />
        <span v-if="app.installing" class="loader"></span>
      </div>
      <div class="d-flex flex-column text-center">
        <span class="app-display-name" :style="{ cursor: app.parentPolicy ? 'default' : 'pointer' }">
          {{ $vuntangle.$t(app.displayName) }}
        </span>
        <span v-if="app.parentPolicy" class="parent-policy">[{{ app.parentPolicy }}]</span>
      </div>
    </v-card-text>
  </v-card>
</template>

<script>
  export default {
    name: 'AppCard',
    props: {
      app: {
        type: Object,
        required: true,
      },
    },
    data() {
      return {
        hovered: false,
      }
    },
    methods: {
      goToApp(app) {
        this.$router.push(`/apps/${this.$route.params.policyId}/${app.appName}`)
      },
    },
  }
</script>

<style lang="scss" scoped>
  .app-card {
    position: relative;
    width: 150px;
    height: auto;
    &:hover {
      background-color: #f5f5f5;
    }
  }

  .v-card__text {
    padding-bottom: 0;
  }

  .icon-wrapper {
    position: relative;
    display: inline-block;
    margin-top: 15px;
  }
  .app-display-name {
    font-size: 12px;
    font-weight: bold;
    word-break: keep-all;
    line-height: 1.2;
    color: black !important;
  }

  .license-wrapper {
    position: absolute;
    top: 2px;
    left: 2px;
    right: 2px;
    z-index: 1;
  }

  .license {
    display: block;
    font-size: 11px;
    color: red;
    padding: 2px 5px;
    text-align: center;
    font-weight: bold;
  }

  .parent-policy {
    font-size: 12px;
    position: relative;
    bottom: auto;
    left: auto;
    right: auto;
    background-color: transparent;
    color: black !important;
    margin-top: -4px;
  }

  .loader {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: rgba(0, 0, 0, 0.1);
    border-radius: 4px;
    width: 90px;
    height: 90px;
    margin: 0 auto;
  }

  .loader::after {
    content: '';
    position: absolute;
    top: 50%;
    left: 50%;
    width: 30px;
    height: 30px;
    margin-top: -15px;
    margin-left: -15px;
    border: 3px solid white;
    border-top-color: $arista-blue;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }

  .state {
    position: absolute;
    z-index: 1;
    top: -5px;
    right: -5px;
    background: #858585;
    border-radius: 50%;
    width: 20px;
    height: 20px;
    display: block;
    transition: all 0.3s cubic-bezier(0.23, 1, 0.32, 1);

    &.on {
      background: #69be4d;
    }

    &.inconsistent {
      background: tomato;
    }

    &.powering {
      background: orange;
    }

    i {
      color: #fff;
      display: flex;
      align-items: center;
      justify-content: center;
      height: 100%;
    }
  }

  .installing {
    .state {
      display: none;
    }
    .loader {
      display: block;
    }
    img {
      opacity: 0.1;
    }
  }
  .from-parent {
    .state {
      opacity: 0.8;
    }
    img {
      -webkit-filter: grayscale(1);
      filter: grayscale(1);
      opacity: 0.2;
    }
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
</style>
