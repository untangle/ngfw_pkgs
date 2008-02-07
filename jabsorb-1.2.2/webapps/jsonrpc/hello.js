var jsonrpc;

function onLoad()
{
  jsonrpc = new JSONRpcClient("JSON-RPC");
}

function resultCallback(result, e)
{
  alert("The server replied: " + result);
}

function clickHello()
{
  var whoNode = document.getElementById("who");
  var result = jsonrpc.hello.sayHello(resultCallback, whoNode.value);
}
