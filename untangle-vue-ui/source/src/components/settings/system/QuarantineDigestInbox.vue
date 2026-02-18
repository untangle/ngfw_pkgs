<template>
  <div class="quarantine-digest-inbox">
    <v-container fluid>
      <v-row>
        <v-col cols="12">
          <v-card>
            <v-card-title class="d-flex align-center">
              <v-icon left color="primary">mdi-inbox-multiple</v-icon>
              <span>{{ $t('manage_user_quarantine') }}</span>
              <v-spacer />
              <v-btn color="primary" outlined small :loading="loading" @click="refreshInbox">
                <v-icon left small>mdi-refresh</v-icon>
                {{ $t('refresh') }}
              </v-btn>
            </v-card-title>

            <v-card-text>
              <!-- Email input to search for user -->
              <v-row class="mb-4">
                <v-col cols="12" md="6">
                  <v-text-field
                    v-model="searchEmail"
                    :label="$t('search_user_email')"
                    :rules="emailRules"
                    outlined
                    dense
                    clearable
                    @keyup.enter="loadUserInbox"
                  >
                    <template #prepend-inner>
                      <v-icon color="grey">mdi-magnify</v-icon>
                    </template>
                    <template #append>
                      <v-btn color="primary" small :disabled="!validEmail" :loading="loading" @click="loadUserInbox">
                        {{ $t('search') }}
                      </v-btn>
                    </template>
                  </v-text-field>
                </v-col>
              </v-row>

              <!-- Success message -->
              <v-alert v-if="showSuccess" type="success" text dismissible class="mb-4" @input="showSuccess = false">
                {{ successMessage }}
              </v-alert>

              <!-- Error message -->
              <v-alert v-if="showError" type="error" text dismissible class="mb-4" @input="showError = false">
                {{ errorMessage }}
              </v-alert>

              <!-- Loading state -->
              <div v-if="loading" class="text-center py-12">
                <v-progress-circular indeterminate size="64" color="primary" />
              </div>

              <!-- Empty state -->
              <div v-else-if="!inboxRecords || inboxRecords.length === 0" class="text-center py-12">
                <v-icon size="80" color="grey lighten-1">mdi-inbox</v-icon>
                <p class="text-h6 grey--text mt-4">
                  {{ currentUserEmail ? $t('no_quarantined_emails_for_user') : $t('enter_email_to_view_quarantine') }}
                </p>
              </div>

              <!-- Inbox data table -->
              <v-data-table v-else :headers="headers" :items="inboxRecords" :items-per-page="10" class="elevation-1">
                <template #[`item.selection`]="{ item }">
                  <v-checkbox v-model="item.selected" hide-details class="ma-0 pa-0" />
                </template>

                <template #[`item.subject`]="{ item }">
                  <div class="text-truncate" style="max-width: 300px">
                    {{ item.subject }}
                  </div>
                </template>

                <template #[`item.actions`]="{ item }">
                  <v-btn icon small color="success" :disabled="actionLoading" @click="releaseEmail(item)">
                    <v-icon small>mdi-email-send</v-icon>
                  </v-btn>
                  <v-btn icon small color="error" :disabled="actionLoading" @click="purgeEmail(item)">
                    <v-icon small>mdi-delete</v-icon>
                  </v-btn>
                </template>

                <template #top>
                  <v-toolbar flat>
                    <v-toolbar-title> {{ $t('quarantine_for') }}: {{ currentUserEmail }} </v-toolbar-title>
                    <v-spacer />
                    <v-btn
                      color="success"
                      outlined
                      small
                      :disabled="!hasSelection || actionLoading"
                      @click="releaseSelected"
                    >
                      <v-icon left small>mdi-email-send</v-icon>
                      {{ $t('release_selected') }}
                    </v-btn>
                    <v-btn
                      color="error"
                      outlined
                      small
                      class="ml-2"
                      :disabled="!hasSelection || actionLoading"
                      @click="purgeSelected"
                    >
                      <v-icon left small>mdi-delete</v-icon>
                      {{ $t('purge_selected') }}
                    </v-btn>
                  </v-toolbar>
                </template>
              </v-data-table>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>
    </v-container>
  </div>
</template>

<script>
  import Rpc from '@/util/Rpc'
  import Util from '@/util/util'

  export default {
    name: 'QuarantineDigestInbox',
    data() {
      return {
        /**
         * email address to search for
         */
        searchEmail: '',
        /**
         * current user email being viewed
         */
        currentUserEmail: '',
        /**
         * inbox records for the user
         */
        inboxRecords: [],
        /**
         * show/hide loader
         */
        loading: false,
        /**
         * show/hide action loader
         */
        actionLoading: false,
        /**
         * show/hide success message
         */
        showSuccess: false,
        /**
         * show/hide error message
         */
        showError: false,
        /**
         * success message text
         */
        successMessage: '',
        /**
         * error message text
         */
        errorMessage: '',
        /**
         * email validation rules
         */
        emailRules: [v => !v || /.+@.+\..+/.test(v) || this.$t('email_must_be_valid')],
        /**
         * data table headers
         */
        headers: [
          {
            text: '',
            value: 'selection',
            sortable: false,
            width: '50px',
          },
          {
            text: this.$t('from'),
            value: 'sender',
            sortable: true,
          },
          {
            text: this.$t('subject'),
            value: 'subject',
            sortable: true,
          },
          {
            text: this.$t('date'),
            value: 'date',
            sortable: true,
          },
          {
            text: this.$t('actions'),
            value: 'actions',
            sortable: false,
            align: 'center',
            width: '120px',
          },
        ],
      }
    },
    computed: {
      /**
       * check if email is valid
       */
      validEmail() {
        return this.searchEmail !== '' && /.+@.+\..+/.test(this.searchEmail)
      },
      /**
       * check if any items are selected
       */
      hasSelection() {
        return this.inboxRecords.some(item => item.selected)
      },
    },
    methods: {
      /**
       * Load user inbox quarantine emails
       */
      async loadUserInbox() {
        if (!this.validEmail) {
          return
        }

        this.loading = true
        this.showSuccess = false
        this.showError = false

        try {
          const apiMethod = Rpc.asyncPromise(
            'rpc.appManager.app("smtp").getQuarantineMaintenenceView().getInboxRecordsV2',
            this.searchEmail,
          )
          const result = await apiMethod()

          if (result?.code && result?.message) {
            this.showError = true
            this.errorMessage = result.message
            this.inboxRecords = []
          } else if (Array.isArray(result)) {
            this.currentUserEmail = this.searchEmail
            this.inboxRecords = result.map(record => ({
              ...record,
              selected: false,
            }))
          } else {
            this.inboxRecords = []
          }
        } catch (error) {
          this.showError = true
          this.errorMessage = error.message || this.$t('failed_to_load_inbox')
          this.inboxRecords = []
          Util.handleException(error)
        } finally {
          this.loading = false
        }
      },

      /**
       * Refresh current inbox
       */
      async refreshInbox() {
        if (this.currentUserEmail) {
          this.searchEmail = this.currentUserEmail
          await this.loadUserInbox()
        }
      },

      /**
       * Release a single email
       */
      async releaseEmail(item) {
        await this.performAction('rescue', [item])
      },

      /**
       * Purge a single email
       */
      async purgeEmail(item) {
        await this.performAction('purge', [item])
      },

      /**
       * Release selected emails
       */
      async releaseSelected() {
        const selected = this.inboxRecords.filter(item => item.selected)
        await this.performAction('rescue', selected)
      },

      /**
       * Purge selected emails
       */
      async purgeSelected() {
        const selected = this.inboxRecords.filter(item => item.selected)
        await this.performAction('purge', selected)
      },

      /**
       * Perform action (rescue or purge) on emails
       */
      async performAction(action, items) {
        if (!items || items.length === 0) {
          return
        }

        this.actionLoading = true
        this.showSuccess = false
        this.showError = false

        try {
          const emails = items.map(item => item.mailID || item.id)
          const apiMethod = Rpc.asyncPromise(
            `rpc.appManager.app("smtp").getQuarantineMaintenenceView().${action}`,
            this.currentUserEmail,
            emails,
          )
          const result = await apiMethod()

          if (result?.code && result?.message) {
            this.showError = true
            this.errorMessage = result.message
          } else {
            this.showSuccess = true
            this.successMessage = this.$t(`${action}_success`, { count: items.length })
            // Refresh the inbox
            await this.loadUserInbox()
          }
        } catch (error) {
          this.showError = true
          this.errorMessage = error.message || this.$t(`${action}_failed`)
          Util.handleException(error)
        } finally {
          this.actionLoading = false
        }
      },
    },
  }
</script>

<style scoped>
  .quarantine-digest-inbox {
    padding: 20px 0;
  }
</style>
