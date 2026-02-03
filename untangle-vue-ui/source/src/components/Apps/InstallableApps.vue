<template>
  <div class="d-flex flex-row flex-wrap" style="gap: 14px">
    <v-card
      v-for="(app, key) in apps"
      :key="key"
      :elevation="hoveredApp === key ? 2 : 0"
      :outlined="hoveredApp === key"
      class="app-card"
      style="flex-basis: 24%; height: 150px"
      @mouseover="hoveredApp = key"
      @mouseleave="hoveredApp = null"
    >
      <div class="d-flex align-center fill-height">
        <div style="width: 120px">
          <v-hover v-slot="{ hover }">
            <div class="text-center pa-2" style="position: relative">
              <img
                :src="require(`@/assets/icons/apps/${app.name}.svg`)"
                width="80"
                height="80"
                alt="App icon"
                :style="{ filter: hover ? 'blur(2px)' : 'none', opacity: hover ? 0.6 : 1 }"
              />
              <v-icon
                v-if="hover"
                size="52"
                color="black"
                style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%)"
                >mdi-download</v-icon
              >
            </div>
          </v-hover>
        </div>
        <div>
          <v-card-title
            data-testid="report-category-title"
            :class="`py-0 subtitle-1 ${$vuntangle.theme === 'dark' ? '' : 'primary--text'}`"
          >
            <div class="d-flex flex-column">
              <span class="font-weight-medium text-left">{{ $vuntangle.$t(app.displayName) }} </span>
            </div>
          </v-card-title>
          <v-card-text style="line-height: 1.2 !important">
            <span class="caption text-left text-justify" style="word-break: normal">{{ app.description }}</span>
          </v-card-text>
        </div>
      </div>
    </v-card>
  </div>
</template>

<script>
  export default {
    name: 'InstallableApps',
    props: {
      apps: {
        type: Array,
        required: true,
      },
    },
    data() {
      return {
        hoveredApp: null,
      }
    },
  }
</script>
