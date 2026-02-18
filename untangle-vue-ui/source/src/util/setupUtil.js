// utils/util.js
import axios from 'axios'
import vuntangle from '@/plugins/vuntangle'
import HandleExceptionAlert from '@/components/Reusable/HandleExceptionAlert.vue'

const Util = {
  ignoreExceptions: false,
  v4NetmaskList: [
    [32, '/32 - 255.255.255.255'],
    [31, '/31 - 255.255.255.254'],
    [30, '/30 - 255.255.255.252'],
    [29, '/29 - 255.255.255.248'],
    [28, '/28 - 255.255.255.240'],
    [27, '/27 - 255.255.255.224'],
    [26, '/26 - 255.255.255.192'],
    [25, '/25 - 255.255.255.128'],
    [24, '/24 - 255.255.255.0'],
    [23, '/23 - 255.255.254.0'],
    [22, '/22 - 255.255.252.0'],
    [21, '/21 - 255.255.248.0'],
    [20, '/20 - 255.255.240.0'],
    [19, '/19 - 255.255.224.0'],
    [18, '/18 - 255.255.192.0'],
    [17, '/17 - 255.255.128.0'],
    [16, '/16 - 255.255.0.0'],
    [15, '/15 - 255.254.0.0'],
    [14, '/14 - 255.252.0.0'],
    [13, '/13 - 255.248.0.0'],
    [12, '/12 - 255.240.0.0'],
    [11, '/11 - 255.224.0.0'],
    [10, '/10 - 255.192.0.0'],
    [9, '/9 - 255.128.0.0'],
    [8, '/8 - 255.0.0.0'],
    [7, '/7 - 254.0.0.0'],
    [6, '/6 - 252.0.0.0'],
    [5, '/5 - 248.0.0.0'],
    [4, '/4 - 240.0.0.0'],
    [3, '/3 - 224.0.0.0'],
    [2, '/2 - 192.0.0.0'],
    [1, '/1 - 128.0.0.0'],
    [0, '/0 - 0.0.0.0'],
  ],

  getNetmask(prefix) {
    const netMask = this.v4NetmaskList.find(i => i[0] === prefix)
    return netMask ? netMask[1].split(' - ')[1] : ''
  },
  setRpcJsonrpc(root) {
    let setupInfo
    let rpcResponse = null

    try {
      const rpc = {
        jsonrpc: new window.JSONRpcClient(`/${root}/JSON-RPC`),
      }

      setupInfo = rpc.jsonrpc.UvmContext
        ? rpc.jsonrpc.UvmContext.getSetupStartupInfo()
        : rpc.jsonrpc.SetupContext.getSetupWizardStartupInfo()

      Object.assign(rpc, setupInfo)
      rpcResponse = rpc
    } catch (error) {
      rpcResponse = null
    }

    return rpcResponse
  },

  getDecryptedPassword(encryptedPassword) {
    return window.rpc.systemManager.getDecryptedPassword(encryptedPassword)
  },

  keyStr: 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=',

  utf8Encode(string) {
    string = string.replace(/\r\n/g, '\n')
    let utftext = ''

    for (let n = 0; n < string.length; n++) {
      const c = string.charCodeAt(n)

      if (c < 128) {
        utftext += String.fromCharCode(c)
      } else if (c < 2048) {
        utftext += String.fromCharCode((c >> 6) | 192)
        utftext += String.fromCharCode((c & 63) | 128)
      } else {
        utftext += String.fromCharCode((c >> 12) | 224)
        utftext += String.fromCharCode(((c >> 6) & 63) | 128)
        utftext += String.fromCharCode((c & 63) | 128)
      }
    }

    return utftext
  },

  base64encode(input) {
    let output = ''
    let chr1, chr2, chr3
    let enc1, enc2, enc3, enc4
    let i = 0

    input = this.utf8Encode(input)

    while (i < input.length) {
      chr1 = input.charCodeAt(i++)
      chr2 = input.charCodeAt(i++)
      chr3 = input.charCodeAt(i++)

      enc1 = chr1 >> 2
      enc2 = ((chr1 & 3) << 4) | (chr2 >> 4)
      enc3 = ((chr2 & 15) << 2) | (chr3 >> 6)
      enc4 = chr3 & 63

      if (isNaN(chr2)) {
        enc3 = enc4 = 64
      } else if (isNaN(chr3)) {
        enc4 = 64
      }

      output +=
        this.keyStr.charAt(enc1) + this.keyStr.charAt(enc2) + this.keyStr.charAt(enc3) + this.keyStr.charAt(enc4)
    }

    return output
  },

  authenticate(password, cb) {
    const url = '/auth/login?url=/admin&realm=Administrator'

    axios
      .post(
        url,
        new URLSearchParams({
          username: 'admin',
          password,
        }),
        {
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        },
      )
      .then(response => {
        if (response.data && response.data.includes('loginPage')) {
          if (password === 'passwd') {
            cb(null, true) // Default success callback for 'passwd'
          } else {
            vuntangle.toast.add(`Invalid password provided.`)
            cb(new Error('Invalid password.'), false)
          }
          return
        }

        this.setRpcJsonrpc('admin')

        const adminRpc = new window.JSONRpcClient('/admin/JSON-RPC')
        const rpc = {
          tolerateKeepAliveExceptions: false,
          keepAlive() {
            if (adminRpc.UvmContext) {
              adminRpc.UvmContext.getFullVersion((result, exception) => {
                if (!rpc.tolerateKeepAliveExceptions && exception) {
                  Util.handleException(exception)
                  return
                }
                setTimeout(() => rpc.keepAlive(), 300000)
              })
            }
          },
        }

        rpc.keepAlive()
        cb(null, true)
      })
      .catch(error => {
        vuntangle.toast.add(`Error during authentication: ${error || error.message}`)
        cb(new Error('Authentication request failed.'), false)
      })
  },

  // save and update wizard settings
  async updateWizardSettings(step) {
    const rpc = this.setRpcJsonrpc('setup')
    const adminRpc = this.setRpcJsonrpc('admin')
    if (!rpc.wizardSettings.wizardComplete) {
      rpc.wizardSettings.completedStep = step
      if (adminRpc.jsonrpc.UvmContext) {
        await adminRpc.jsonrpc.UvmContext.setWizardSettings(rpc.wizardSettings)
      }
    }
  },

  /** Validates multiple tabs within a component using ValidationObserver. */
  /**
   * Asynchronously validates multiple tabs within a component.
   * It iterates through each tab, validates it using its ref, and tracks the first invalid tab.
   * If an invalid tab is found and a setSelectedTab function is provided, it sets the active tab to the invalid one.
   *
   * @param {Array<Object>} params.tabs - An array of tab objects, each expected to have a 'key' and 'valid' property.
   * @param {Object} params.refs - An object containing references to the validation components for each tab, keyed by tab.key.
   * @param {Function} [params.setSelectedTab] - An optional function to set the currently selected tab.
   * @returns {Promise<boolean>} A promise that resolves to true if all tabs are valid, false otherwise.
   */
  async validateTabs({ tabs, refs, setSelectedTab }) {
    let invalidTab = null

    const promises = tabs.map(async tab => {
      if (!refs[tab.key]) {
        tab.valid = true
        return true
      }
      const valid = await refs[tab.key].validate()
      tab.valid = valid

      if (!valid && !invalidTab) {
        invalidTab = tab.key
      }
      return valid
    })

    const results = await Promise.all(promises)

    if (invalidTab && setSelectedTab) {
      setSelectedTab(invalidTab)
    }

    return !results.includes(false)
  },

  isDestroyed(...args) {
    return args.some(arg => typeof arg === 'object' && arg?.$isUnmounted)
  },

  handleException(exception) {
    if (Util.ignoreExceptions) return
    if (!exception) {
      vuntangle.toast.add(`Null Exception!`)
      return
    }

    let details = ''
    if (exception.message) {
      details += `<b>Exception Message:</b> ${exception.message.replace(/\n/g, '<br/>')}<br/><br/>`
    }
    if (exception.javaStack) {
      details += `<b>Exception Java Stack:</b> ${exception.javaStack.replace(/\n/g, '<br/>')}<br/><br/>`
    }
    if (exception.stack) {
      details += `<b>Exception JS Stack:</b> ${exception.stack.replace(/\n/g, '<br/>')}<br/><br/>`
    }
    if (window.rpc?.fullVersionAndRevision) {
      details += `<b>Build:</b> ${window.rpc.fullVersionAndRevision}<br/><br/>`
    }
    details += `<b>Timestamp:</b> ${new Date().toString()}<br/><br/>`

    if (exception.response) {
      details += `<b>Exception Response:</b> ${exception.response.replace(/\s+/g, '<br/>')}<br/><br/>`
    }

    /** Handle Invalid Security Nonce (Session Expired) */
    if (exception.code === 595 || exception.message?.includes('Invalid security nonce')) {
      this.showWarningMessage(
        'Your session has expired due to a security issue. Please log in again.',
        details,
        this.goToStartPage,
        'OK',
      )
      return
    }

    /** Handle session timeout / authorization lost */
    if (exception.response && exception.response.includes('loginPage')) {
      Util.ignoreExceptions = true
      this.showWarningMessage(
        'Session timed out.Press OK to return to the login page.',
        details,
        this.goToStartPage,
        'OK',
      )
      return
    }

    /** Handle connection lost */
    if (
      exception.code === 550 ||
      exception.code === 12029 ||
      exception.code === 12019 ||
      exception.code === 0 ||
      (exception.name === 'JSONRpcClientException' && exception.fileName?.includes('jsonrpc')) ||
      exception.message?.includes('method not found') ||
      exception.message?.includes('Service Unavailable') ||
      exception.message?.includes('Service Temporarily Unavailable') ||
      exception.message?.includes('This application is not currently available')
    ) {
      Util.ignoreExceptions = true
      this.showWarningMessage(
        'The connection to the server has been lost.Press OK to return to the login page.',
        details,
        this.goToStartPage,
        'Ok',
      )
      return
    }
    if (typeof exception === 'string') {
      this.showWarningMessage(exception, '', this.goToStartPage)
    } else {
      this.showWarningMessage(exception.message || 'An unknown error occurred.', details, this.goToStartPage)
    }
  },

  async showWarningMessage(message, details = '', errorHandler = null, buttonName = null) {
    await vuntangle.toast.add(message)
    await vuntangle.dialog.show({
      title: 'Warning',
      component: HandleExceptionAlert,
      componentProps: {
        alert: { message, details: details || '' },
      },
      width: 600,
      height: 500,
      buttons: [
        {
          name: buttonName || 'Close',
          handler() {
            if (errorHandler) {
              errorHandler()
            }
            this.onClose()
          },
        },
      ],
    })
  },

  goToStartPage() {
    location.reload()
  },
}

export default Util
