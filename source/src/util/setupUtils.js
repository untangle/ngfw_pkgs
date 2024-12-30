// utils/util.js
import axios from 'axios'

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

  setRpcJsonrpc(root) {
    let setupInfo
    let success = true

    try {
      const rpc = {
        jsonrpc: new window.JSONRpcClient(`/${root}/JSON-RPC`),
      }

      setupInfo = rpc.jsonrpc.UvmContext
        ? rpc.jsonrpc.UvmContext.getSetupStartupInfo()
        : rpc.jsonrpc.SetupContext.getSetupWizardStartupInfo()

      Object.assign(rpc, setupInfo)
    } catch (e) {
      success = false
      console.error(e) // Handle the exception here
    }

    return success
  },

  authenticate(password, cb) {
    const url = '/auth/login?url=/admin&realm=Administrator'
    console.log('Authenticating with password:', password)

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
        // console.log('Authentication response:', response.data)

        // Check if loginPage exists in the response
        if (response.data && response.data.includes('loginPage')) {
          if (password === 'passwd') {
            cb(null, true) // Default success callback for 'passwd'
          } else {
            console.error('Invalid password provided.')
            cb(new Error('Invalid password.'), false)
          }
          return
        }

        // Set up RPC JSON-RPC client
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
            } else {
              console.error('UvmContext is not available in RPC.')
            }
          },
        }

        rpc.keepAlive()
        cb(null, true) // Successfully authenticated
      })
      .catch(error => {
        console.error('Error during authentication:', error)
        cb(new Error('Authentication request failed.'), false)
      })
  },

  handleException(exception) {
    if (!exception) {
      console.error('Null Exception!')
      return
    }

    let details = ''
    if (exception.message) {
      details += `<b>Exception message:</b> ${exception.message.replace(/\n/g, '<br/>')}<br/><br/>`
    }
    if (exception.stack) {
      details += `<b>Exception stack:</b> ${exception.stack.replace(/\n/g, '<br/>')}<br/><br/>`
    }

    if (exception.response && exception.response.includes('loginPage')) {
      this.showWarningMessage(
        'Session timed out.<br/>Press OK to return to the login page.',
        details,
        this.goToStartPage,
      )
      return
    }

    this.showWarningMessage('An error occurred', details, this.goToStartPage)
  },

  showWarningMessage(message, details, errorHandler) {
    // Use your modal library here. Example:
    this.$notify({
      title: 'Warning',
      message: `
        <div>
          <p>${message}</p>
          ${details ? `<details><summary>Details</summary><p>${details}</p></details>` : ''}
        </div>
      `,
      type: 'warning',
      dangerouslyUseHTMLString: true,
    })

    if (errorHandler) {
      errorHandler()
    }
  },

  goToStartPage() {
    alert('Redirecting to the start page...')
    location.reload()
  },
}

export default Util
