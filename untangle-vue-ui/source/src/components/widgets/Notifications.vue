<template>
  <u-widget :title="widgetTitle" :enable-expand="false" :fetching="fetching" enable-refresh @refresh="loadData">
    <div style="display: flex; flex-direction: column; height: 100%; padding: 12px">
      <div
        v-if="notifications.length === 0"
        style="text-align: center; font-size: 16px; padding: 40px 20px 20px; color: #555"
      >
        {{ $t('no_notifications') }}
      </div>
      <ul v-else style="margin: 12px 0 0; padding: 0 10px 30px 30px; flex: 1; overflow-y: auto">
        <li
          v-for="(item, idx) in notifications"
          :key="idx"
          style="margin-bottom: 8px; font-size: 15px; color: #444; line-height: 1.5"
          v-html="item"
        />
      </ul>
      <div v-if="notifications.length > 0" style="padding: 4px 8px; border-top: 1px solid #eee">
        <v-btn text small :href="helpUrl" target="_blank" rel="noopener noreferrer">
          <v-icon left small>mdi-help-circle-outline</v-icon>
          {{ $t('help') }}
        </v-btn>
      </div>
    </div>
  </u-widget>
</template>

<script>
  import widgetsMixin from './widgetsMixin'
  import { rpcCall } from '@/util/rpcHelpers'

  function sanitizeNotification(text) {
    const div = document.createElement('div')
    div.appendChild(document.createTextNode(text))
    let safe = div.innerHTML
    // DOM doesn't encode quotes; encode them to match what ExtJS htmlEncode produces
    safe = safe.replace(/"/g, '&quot;')
    safe = safe.replace(/'/g, '&#39;')
    safe = safe.replace(/&lt;br\/&gt;/g, '<br/>')
    safe = safe.replace(/&lt;strong&gt;/g, '<strong>')
    safe = safe.replace(/&lt;\/strong&gt;/g, '</strong>')
    safe = safe.replace(
      /&lt;a href=&quot;((?:\/[^&]*|https:\/\/[a-zA-Z0-9.-]+\.arista\.com\/[^&]*)?)&quot;(?:\s*target=&quot;_blank&quot;)?&gt;(.*?)&lt;\/a&gt;/g,
      '<a href="$1" target="_blank" rel="noopener noreferrer">$2</a>',
    )
    safe = safe.replace(
      /&lt;a href=&#39;((?:\/[^&]*|https:\/\/[a-zA-Z0-9.-]+\.arista\.com\/[^&]*)?)&#39;(?:\s*target=&#39;_blank&#39;)?&gt;(.*?)&lt;\/a&gt;/g,
      '<a href="$1" target="_blank" rel="noopener noreferrer">$2</a>',
    )
    return safe
  }

  export default {
    mixins: [widgetsMixin],

    data: () => ({
      fetching: false,
      notifications: [],
    }),

    computed: {
      widgetTitle() {
        return `${this.$t('notifications')} (${this.notifications.length})`
      },
      helpUrl() {
        const base = window.rpc?.helpUrl || ''
        return `${base}?fragment=${window.location.hash.slice(1)}`
      },
    },

    methods: {
      async loadData() {
        this.fetching = true
        const result = await rpcCall(window.rpc?.notificationManager?.getNotifications, [], { fallback: null })
        if (result?.list?.length > 0) {
          this.notifications = result.list.map(item => sanitizeNotification(item))
        } else {
          this.notifications = []
        }
        this.fetching = false
      },
    },
  }
</script>
