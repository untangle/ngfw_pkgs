import Util from '@/util/setupUtil'

// Creating one RPC client for “admin”
const rpcClient = Util.setRpcJsonrpc('admin')
if (!rpcClient) {
  console.error('Unable to init RPC client for "admin"')
}

// Build the Vue plugin object. When installed, it will attach
const RpcPlugin = {
  install(Vue) {
    Vue.prototype.$rpcClient = rpcClient
  },
}

// rpcClient as the default export, and RpcPlugin as a named export:
export default rpcClient
export { RpcPlugin }
