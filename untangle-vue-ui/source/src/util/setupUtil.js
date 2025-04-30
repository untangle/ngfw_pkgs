// utils/util.js
import axios from 'axios'
import vuntangle from '@/plugins/vuntangle'
import HandleExceptionAlert from '@/components/Reusable/HandleExceptionAlert.vue'

const Util = {
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

  handleException(exception) {
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
