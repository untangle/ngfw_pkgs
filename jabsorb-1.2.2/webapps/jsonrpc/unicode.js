var jsonurl = "JSON-RPC",
    jsonrpc = null,
    tbody;

function onLoad()
{
  tbody = document.getElementById("tests");

  try
  {
    jsonrpc = new JSONRpcClient(jsonurl);
    jsonrpc.unicode.getTests(processTests);
  }
  catch(e)
  {
    if (e.message)
    {
      alert(e.message);
    }
    else
    {
      alert(e);
    }
  }
}

function processTests(result, e)
{

  if (e)
  {
    alert(e);
    return;
  }

  var i=0,
    row,
    dcell,
    rcell,
    scell,
    pcell;

  jsonrpc.unicode.compareTests(processCompares, result);

  for (var key in result.map)
  {
    i++;
    row = document.createElement("tr");
    row.className = "tr" + i%2;

    dcell = document.createElement("td");
    rcell = document.createElement("td");
    scell = document.createElement("td");
    pcell = document.createElement("td");

    dcell.innerHTML = "<div class=\"desc_cell\">" +
                      result.map[key].description + "</div>";
    dcell.className = "test_td";
    rcell.className = "test_td";
    rcell.innerHTML = "<div class=\"recv_cell\">" +
                      result.map[key].data + "</div>";
    scell.className = "test_td";
    scell.id = "send." + key;
    pcell.className = "test_td";
    pcell.id = "pass." + key;

    row.appendChild(dcell);
    row.appendChild(rcell);
    row.appendChild(scell);
    row.appendChild(pcell);
    tbody.appendChild(row);
  }
}

function processCompares(result, e)
{
  if (e)
  {
    alert(e);
    return;
  }

  var scell,pcell;

  for (var key in result.map)
  {
    if (typeof result.map[key] != "object")
    {
      continue;
    }
    scell = document.getElementById("send." + key);
    pcell = document.getElementById("pass." + key);
    scell.innerHTML = "<div class=\"echo_cell\">" +
                      result.map[key].data + "</div>";
    if (result.map[key].compares)
    {
      pcell.innerHTML = "<div class=\"pass_cell\">pass</div>";
    }
    else
    {
      pcell.innerHTML = "<div class=\"fail_cell\">fail</pass>";
    }
  }
}
