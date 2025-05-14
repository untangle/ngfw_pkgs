<template>
  <!-- <table class="text-body-2">
    <tbody>
      <tr>
        <td class="px-2 text-left" v-html="alert.message"></td>
      </tr>
    </tbody>
  </table> -->
  <v-card width="1100" class="mx-auto mt-3 pa-3" flat>
    <div class="ma-2">
      <br />
      <p class="ma-2 font-weight-light faint-color text-h6">
        This step identifies the external, internal, and other network cards.
      </p>

      <div class="ma-2">
        <p>
          <strong>Step 1:</strong>
          <span class="ml-2">Plug an active cable into one network card to determine which network card it is. </span
          ><br />
          <strong>Step 2:</strong>
          <span class="ml-2">Drag and drop the network card to map it to the desired interface.</span>
          <br />
          <strong>Step 3:</strong>
          <span class="ml-2">Repeat steps 1 and 2 for each network card and then click <i>Next</i>.</span>
        </p>
      </div>
      <!-- <v-card class="ma-2">
        <v-data-table
          :headers="tableFields"
          :items="gridData"
          item-value="id"
          hide-default-footer
          class="border border-black"
        >
          <template #item="{ item }">
            <tr class="text-center align-middle">
              <td v-for="(value, key) in item" :key="key" class="text-center align-center">
                {{ value }}
              </td>
            </tr>
          </template>
          <template #body>
            <draggable
              v-model="gridData"
              :group="{ name: 'network-rows', pull: 'clone' }"
              tag="tbody"
              handle=".drag-handle"
              :move="onBeforeDrop"
              @start="onDragStart"
              @end="onDragEnd"
              @drag="onDrag"
              @drop="onDrop"
            >
              <tr v-for="item in gridData" :key="item.id">
                <td>{{ item.name }}</td>
                <td>
                  <v-icon class="drag-handle cursor-grab">mdi-drag</v-icon>
                </td>
                <td>
                  <v-select
                    v-model="item.physicalDev"
                    :items="deviceStore.map(device => device.physicalDev)"
                    variant="outlined"
                    density="compact"
                    class="bg-grey-lighten-4 text-black border border-black d-flex align-center justify-center"
                    style="width: 80px; height: 36px"
                    menu-icon="mdi-chevron-down"
                    @change="newValue => setInterfacesMap(item, newValue)"
                  ></v-select>
                </td>
                <td>
                  <v-avatar size="12" class="mx-3" :class="statusIcon(item.connected)"></v-avatar>
                </td>
                <td>{{ getConnectedStr(item) }}</td>
                <td>{{ item.macAddress }}</td>
              </tr>
            </draggable>
          </template>
        </v-data-table>
      </v-card> -->
    </div>
  </v-card>
</template>

<script>
  export default {
    props: {
      alert: {
        type: Object,
        required: true,
      },
    },
    created() {
      console.log('****', this.alert.message)
      console.log('****', this.alert.interfaces)
    },
  }
</script>
