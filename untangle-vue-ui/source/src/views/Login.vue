<template>
  <v-container class="d-flex">
    <div class="d-flex flex-column align-center mt-15">
      <v-img :src="require(`@/assets/${logo}`)" width="240" height="40" contain />
      <p class="aristaBlue--text font-weight-bold text-h6">NGFW</p>
      <v-card-title>{{ $t('sign_in') }}</v-card-title>
      <div style="position: relative">
        <v-divider class="mb-8" />
        <u-alert v-if="error" :error="true" class="body-2 mb-4">
          <div v-html="$t('invalid_username_or_password')" />
        </u-alert>
        <ValidationObserver ref="obs" v-slot="{ passes }">
          <v-form>
            <ValidationProvider v-slot="{ errors }" name="username" rules="required">
              <u-text-field
                v-model="credentials.username"
                class="mb-4"
                :label="usernameHadFocus ? $t('username') : ''"
                prepend-inner-icon="mdi-account"
                :error-messages="errors"
                :dense="false"
                :placeholder="$t('username')"
                @keyup="$event.keyCode === 13 ? passes(login) : null"
                @focus="usernameHadFocus = true"
              >
                <template v-if="errors.length" #append>
                  <u-errors-tooltip :errors="errors" />
                </template>
              </u-text-field>
            </ValidationProvider>
            <ValidationProvider v-slot="{ errors }" name="password" rules="required">
              <u-text-field
                v-model="credentials.password"
                :append-icon="passwordReveal ? 'mdi-eye' : 'mdi-eye-off'"
                :type="passwordReveal ? 'text' : 'password'"
                :label="passwordHadFocus ? $t('password') : ''"
                :error-messages="errors"
                :dense="false"
                class="mb-4"
                prepend-inner-icon="mdi-lock"
                :placeholder="$t('password')"
                @click:append="passwordReveal = !passwordReveal"
                @keyup="$event.keyCode === 13 ? passes(login) : null"
                @focus="passwordHadFocus = true"
              >
                <template v-if="errors.length" #append>
                  <u-errors-tooltip :errors="errors" />
                </template>
              </u-text-field>
            </ValidationProvider>
            <v-btn large block depressed color="primary" @click="passes(login)">
              {{ $t('sign_in') }}
            </v-btn>
          </v-form>
        </ValidationObserver>
      </div>
    </div>
  </v-container>
</template>
<script>
  import api from '@/plugins/api'

  export default {
    data() {
      return {
        credentials: {
          username: 'admin',
          password: 'passwd',
        },
        error: false,

        // boolean used to reveal password field
        passwordReveal: false,

        /**
         * Workaround for email/password autocomplete overlapping vuetify label/placeholder behavior.  Once
         * the field has had focus the vuetify label behavior will work like normal.
         */
        usernameHadFocus: false,
        passwordHadFocus: false,
      }
    },

    computed: {
      logo() {
        return this.$vuetify.theme.isDark ? 'arista-logo-white.svg' : 'arista-logo-blue.svg'
      },
    },

    methods: {
      async login() {
        this.error = false
        const response = await api.post('/auth/login?url=/admin&realm=Administrator', this.credentials)
        if (!response.data.includes('login-form')) {
          this.$router.push({ name: 'home' })
        }
      },
    },
  }
</script>
