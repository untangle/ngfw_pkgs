// src/utils/rpc.js

import Util from './setupUtil'

export default {
  getCommand(...args) {
    let path = args[0]
    let commandArgs
    let method = null
    let context
    const result = {
      context: null,
      args: null,
      error: null,
    }

    if (!path) {
      result.error = 'Null path or RPC object'
      return result
    } else if (typeof path === 'object') {
      commandArgs = args.slice(2)
      context = args[0]
      path = args[1]
    } else {
      commandArgs = args.slice(1)
      context = window // Or replace with your app's global RPC context
    }

    const nodes = path.split('.')
    method = nodes.pop()

    for (let i = 0; i < nodes.length; i++) {
      if (!context) {
        result.error = `Invalid RPC path: '${path}'`
        return result
      }

      let node = nodes[i]

      // If function-like syntax: e.g., getApp("Firewall")
      if (node.includes('(') && node.includes(')')) {
        const argList = node.substring(node.indexOf('(') + 1, node.indexOf(')')).split(',')
        const cleanArgs = argList.map(arg => arg.replace(/"/g, '').trim()).filter(Boolean)
        node = node.split('(')[0]

        if (typeof context[node] === 'function') {
          context = context[node](...cleanArgs)
        } else {
          context = context[node]
        }
      } else if (typeof context[node] === 'function') {
        context = context[node]()
      } else {
        context = context[node]
      }
    }

    if (!context || !method || typeof context[method] !== 'function') {
      result.error = `No such method: '${path}'`
      return result
    }

    result.context = context[method]
    result.args = commandArgs
    return result
  },

  asyncData(...args) {
    const commandResult = this.getCommand(...args)

    if (!commandResult.context) {
      return Promise.reject(new Error(commandResult.error))
    }

    if (typeof commandResult.context !== 'function') {
      return Promise.reject(new Error(`Path '${args[0]}' is not a function, use a direct method instead`))
    }

    return new Promise((resolve, reject) => {
      commandResult.args.unshift((result, ex) => {
        if (ex) {
          this.processException(null, ex, true)
          reject(ex)
        } else {
          resolve(result)
        }
      })

      commandResult.context(...commandResult.args)
    })
  },

  asyncPromise(...args) {
    const commandResult = this.getCommand(...args)

    if (commandResult.context != null && typeof commandResult.context !== 'function') {
      return () => Promise.reject(new Error(`Path '${args[0]}' is not a function, use a direct method instead`))
    }

    if (commandResult.context == null) {
      return () => Promise.reject(new Error(commandResult.error))
    }

    return () => {
      return new Promise((resolve, reject) => {
        commandResult.args.unshift((result, ex) => {
          if (ex) {
            this.processException(null, ex, true)
            reject(ex)
          } else {
            resolve(result)
          }
        })

        commandResult.context(...commandResult.args)
      })
    }
  },

  directPromise(...args) {
    const commandResult = this.getCommand(...args)

    if (!commandResult.context) {
      return Promise.reject(commandResult.error)
    } else {
      return () => {
        return new Promise((resolve, reject) => {
          try {
            const result =
              typeof commandResult.context === 'function'
                ? commandResult.context(...commandResult.args)
                : commandResult.context

            resolve(result)
          } catch (ex) {
            this.handleRpcException(reject, ex, false)
          }
        })
      }
    }
  },

  processException(_, ex, handle = true) {
    if (ex?.message?.includes('method not found')) {
      ex.message = 'Possible argument mismatch: ' + ex.message
    }

    if (handle) {
      console.error('RPC Exception:', ex.message || ex)
    }
  },
  directData(...args) {
    const commandResult = this.getCommand(...args)
    if (!commandResult.context) {
      if (typeof Util?.handleException === 'function') {
        Util.handleException(commandResult.error?.toString())
      }
      throw new Error(commandResult.error)
    }

    try {
      return typeof commandResult.context === 'function'
        ? commandResult.context(...commandResult.args)
        : commandResult.context
    } catch (ex) {
      this.processException(null, ex, true)
      return null
    }
  },
}
