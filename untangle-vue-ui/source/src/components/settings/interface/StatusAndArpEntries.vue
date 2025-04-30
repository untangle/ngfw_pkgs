<template>
  <div :class="['d-flex flex-column', { 'resizing-active': isResizing }]">
    <div ref="resizableWrapper" class="d-flex w-100 fill-height">
      <!-- Left Pane -->
      <div class="overflow-auto transition-fast" :style="{ width: leftWidth + '%' }">
        <!-- Status Table  -->
        <InterfacesTable
          title="Status"
          :headers="statusHeaders"
          :items="statusRows"
          :dense="true"
          :loading="statusLoading"
          @refresh="$emit('refresh-table', 'status')"
        />
      </div>

      <!-- Resizer -->
      <div
        class="d-flex align-center justify-center grey lighten-2"
        style="width: 7px; cursor: col-resize"
        @mousedown="startResize"
      >
        <div class="d-flex flex-column align-center" style="gap: 10px"></div>
      </div>

      <!-- Right Pane -->
      <div class="overflow-auto transition-fast" :style="{ width: 100 - leftWidth + '%' }">
        <!-- ARP Entries -->
        <InterfacesTable
          title="ARP Entries"
          :headers="headersForArp"
          :items="arpEntries"
          :dense="true"
          :loading="arpLoading"
          @refresh="$emit('refresh-table', 'arp')"
        />
      </div>
    </div>
  </div>
</template>

<script>
  import InterfacesTable from './InterfacesDetailsTable.vue'

  export default {
    components: { InterfacesTable },

    props: {
      interfaceSourceConfig: {
        type: Object,
        required: true,
      },
      interfaceStatusData: {
        type: Object,
        required: true,
      },
      arpEntries: {
        type: Array,
        default: () => [],
      },
      statusLoading: {
        type: Boolean,
        default: false,
      },
      arpLoading: {
        type: Boolean,
        default: false,
      },
    },

    data() {
      return {
        leftWidth: 50,
        isResizing: false,
        minLeftWidth: 20,
        maxLeftWidth: 80,
        headersForArp: [
          { text: 'MAC Address', align: 'start', sortable: true, value: 'macAddress' },
          { text: 'IP Address', align: 'start', sortable: true, value: 'address' },
          { text: 'MAC Vendor', align: 'start', sortable: true, value: 'vendor' },
        ],
      }
    },

    computed: {
      statusHeaders() {
        return [
          { text: 'Name', value: 'name', sortable: true },
          { text: 'Value', value: 'value', sortable: true },
        ]
      },
      statusRows() {
        return Object.entries(this.interfaceSourceConfig).map(([key, config]) => ({
          name: config.displayName || key,
          value: this.interfaceStatusData?.[key] ?? '-',
        }))
      },
    },

    methods: {
      startResize() {
        this.isResizing = true
        document.body.style.userSelect = 'none'
        document.addEventListener('mousemove', this.onResize)
        document.addEventListener('mouseup', this.stopResize)
      },
      onResize(e) {
        if (!this.isResizing) return
        const containerWidth = this.$refs.resizableWrapper.offsetWidth
        const newLeftWidth = (e.clientX / containerWidth) * 100
        if (newLeftWidth >= this.minLeftWidth && newLeftWidth <= this.maxLeftWidth) {
          this.leftWidth = newLeftWidth
        }
      },
      stopResize() {
        this.isResizing = false
        document.body.style.userSelect = ''
        document.removeEventListener('mousemove', this.onResize)
        document.removeEventListener('mouseup', this.stopResize)
      },
    },
  }
</script>

<style>
  .resizing-active {
    user-select: none;
  }
</style>
