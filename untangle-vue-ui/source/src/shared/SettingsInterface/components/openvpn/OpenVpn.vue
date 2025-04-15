<template>
  <div>
    <v-row>
      <v-col cols="8">
        <ValidationProvider v-slot="{ errors }" :rules="{ required: !openvpnConf }">
          <v-file-input
            v-model="file"
            truncate-length="15"
            outlined
            dense
            :prepend-icon="null"
            :label="$t('select_file_from_disk')"
            hide-details
            :error-messages="errors"
            @change="onFileChange"
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </v-file-input>
        </ValidationProvider>
      </v-col>
      <v-col class="d-flex justify-end">
        <v-checkbox v-model="enableInlineEdit" small :label="$t('inline_edit')" hide-details class="ma-0" />
      </v-col>
    </v-row>

    <v-row>
      <v-col>
        <ValidationProvider v-slot="{ errors }" rules="required">
          <v-textarea
            v-model="openvpnConf"
            outlined
            :placeholder="$t('no_file_selected')"
            :readonly="!enableInlineEdit"
            hide-details
            class="file-content"
            rows="10"
            :error-messages="errors"
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </v-textarea>
        </ValidationProvider>
      </v-col>
    </v-row>

    <!-- openvpnUsernamePasswordEnabled -->
    <v-row>
      <v-col>
        <v-checkbox v-model="intf.openvpnUsernamePasswordEnabled" :label="$t('requires_authentication')" hide-details />
      </v-col>
    </v-row>

    <!-- CD-5618 added autocomplete="one-time-code" to trick the browser and prevent fields autofill with preexisting emails/passwords -->
    <v-row v-if="intf.openvpnUsernamePasswordEnabled" dense>
      <v-col>
        <!-- openvpnUsername -->
        <ValidationProvider v-slot="{ errors }" :rules="{ required: intf.openvpnUsernamePasswordEnabled }">
          <u-text-field
            v-model="intf.openvpnUsername"
            :label="$t('username')"
            :error-messages="errors"
            autocomplete="one-time-code"
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
      <v-col>
        <!-- openvpnPassword -->
        <ValidationProvider v-slot="{ errors }" :rules="{ required: intf.openvpnUsernamePasswordEnabled, min: 6 }">
          <u-text-field
            v-model="openvpnPassword"
            :label="$t('password')"
            type="password"
            :error-messages="errors"
            autocomplete="one-time-code"
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
    </v-row>
    <!-- openvpnPeerDns -->
    <v-row>
      <v-col>
        <v-checkbox v-model="intf.openvpnPeerDns" :label="$t('use_peer_dns')" hide-details class="ma-0" />
      </v-col>
    </v-row>
  </div>
</template>
<script>
  import { VRow, VCol, VCheckbox, VFileInput, VTextarea } from 'vuetify/lib'

  export default {
    components: { VRow, VCol, VCheckbox, VFileInput, VTextarea },
    inject: ['$intf', '$status'],
    data() {
      return {
        file: null,
        enableInlineEdit: false,
      }
    },
    /**
     * the conf and password are base64 encoded
     * using computed props to get and set values
     */
    computed: {
      intf: ({ $intf }) => $intf(),
      status: ({ $status }) => $status(),

      openvpnConf: {
        get() {
          const conf = this.intf.openvpnConfFile.contents
          return conf ? window.atob(conf) : ''
        },
        set(value) {
          this.intf.openvpnConfFile.contents = window.btoa(value)
        },
      },
      openvpnPassword: {
        get() {
          const pass = this.intf.openvpnPasswordBase64
          return pass ? window.atob(pass) : ''
        },
        set(value) {
          this.intf.openvpnPasswordBase64 = window.btoa(value)
        },
      },
    },
    methods: {
      onFileChange(file) {
        if (!file) {
          this.openvpnConf = null
          return
        }
        const reader = new FileReader()
        reader.onload = () => {
          this.openvpnConf = reader.result
        }
        reader.readAsText(file)
      },
    },
  }
</script>
<style>
  .file-content textarea {
    font-family: monospace;
    font-size: 12px;
    line-height: 1.5;
    margin: 0 10px 10px 0;
  }
</style>
