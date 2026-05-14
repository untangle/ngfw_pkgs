<template>
  <v-dialog v-model="isOpen" max-width="600">
    <v-card v-if="isOpen">
      <v-card-title
        :class="`subtitle-1 ${$vuntangle.theme === 'dark' ? '' : 'primary--text'}`"
        data-testid="report-dialog-title"
      >
        <span class="font-weight-medium">{{ categoryKey }}</span>
        <v-spacer />
        <v-btn icon @click="close">
          <v-icon>mdi-close</v-icon>
        </v-btn>
      </v-card-title>
      <v-divider />
      <v-list dense class="pt-0">
        <v-list-item
          v-for="view in currentCard"
          :key="view.id"
          @click="
            $emit('view-report', view.id)
            close()
          "
        >
          <v-list-item-content>
            <v-list-item-title>{{ view.name }}</v-list-item-title>
            <v-list-item-subtitle class="font-weight-regular caption" style="white-space: unset">
              <span v-for="reportId in view.reports" :key="reportId" class="mr-4">
                <v-icon small>{{ reports[reportId].icon }}</v-icon>
                {{ reports[reportId].title }}
              </span>
            </v-list-item-subtitle>
          </v-list-item-content>
        </v-list-item>
      </v-list>
    </v-card>
  </v-dialog>
</template>
<script>
  import {
    VDialog,
    VCard,
    VCardTitle,
    VDivider,
    VList,
    VListItem,
    VListItemContent,
    VListItemTitle,
    VListItemSubtitle,
    VIcon,
    VBtn,
    VSpacer,
  } from 'vuetify/lib'

  export default {
    components: {
      VDialog,
      VCard,
      VCardTitle,
      VDivider,
      VList,
      VListItem,
      VListItemContent,
      VListItemTitle,
      VListItemSubtitle,
      VIcon,
      VBtn,
      VSpacer,
    },

    props: {
      cards: { type: Object, required: true },
      reports: { type: Object, required: true },
    },

    emits: ['view-report'],

    data() {
      return {
        isOpen: false,
        categoryKey: null,
      }
    },

    computed: {
      currentCard() {
        return this.categoryKey ? this.cards[this.categoryKey] ?? [] : []
      },
    },

    methods: {
      open(key) {
        this.categoryKey = key
        this.isOpen = true
      },

      close() {
        this.isOpen = false
        this.categoryKey = null
      },
    },
  }
</script>
