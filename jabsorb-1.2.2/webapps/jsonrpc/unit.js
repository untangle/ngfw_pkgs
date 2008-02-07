var jsonurl = "JSON-RPC";

//bridge reference
var jsonrpc = null;

//callback function
var cb;

//when the tests started
var tests_start;

//The difference of the width of detail tables vs the main table
var innerTableWidthDifference=30;

//from prototype.js
var $A = function(iterable)
{
  var results,i,length;
  if (!iterable)
  {
    return [];
  }
  if (iterable.toArray)
  {
    return iterable.toArray();
  }
  else
  {
    results = [];
    i=0;
    length = iterable.length;
    for (; i < length; i++)
    {
      results.push(iterable[i]);
    }
    return results;
  }
};

//from prototype.js
Function.prototype.bind = function() {
  var __method = this, args = $A(arguments), object = args.shift();
  return function()
  {
  
    __method.apply(object, args.concat($A(arguments)));
    return false;
  };
};

//from prototype.js
Function.prototype.bindAsEventListener = function() {
  var __method = this, args = $A(arguments), object = args.shift();
  return function(event) {
    __method.apply(object, [event || window.event].concat(args));
    return false;
  };
};

//shorthand to save typing
function $n(nodeType)
{
  return document.createElement(nodeType);
}
//removes all elements of the array "name", from an object
function clearChildren(node,name)
{
  if(!node)
  {
    return;
  }
  if(!name)
  {
    return;  
  }
  while(node[name].length>0)
  {
    node.removeChild(node[name][0]);
  }
}

// some variables to hold stuff
var tbody,asyncNode,profileNode,maxRequestNode,showSuccessesNode,hideUnrunNode;

//loads page
function onLoad()
{
  asyncNode = document.getElementById("async");
  profileNode = document.getElementById("profile");
  maxRequestNode = document.getElementById("max_requests");
  showSuccessesNode = document.getElementById("showSuccesses");
  hideUnrunNode = document.getElementById("hideUnrun");
  showSuccessesNode.onclick=updateAllTestsVisibility;
  hideUnrunNode.onclick=updateAllTestsVisibility;
  
  jsonrpc = new JSONRpcClient(jsonurl);

  //add the tests table
  var displayTable = createShowTestsTable(); 
  document.getElementById("results").appendChild(displayTable);
}

function updateAllTestsVisibility()
{
  var name;
  for(name in unitTests)
  { 
    updateTestSetVisibility(name);
  }
}
function updateTestSetVisibility(name)
{
  var i,
    row,
    viewableCounter=0,
    tests=unitTests[name].tests;

  for (i = 0; i < tests.length; i++)
  {
    row = document.getElementById(name+"row." + i);

    if(tests[i].completed)
    {
      //if showing successes show the row
      if(showSuccessesNode.checked)
      {
        showTableRow(row);
        viewableCounter++;
      }
      //if it passed and we're hiding successes don't show the row
      else if(tests[i].pass)
      {
        hideTableRow(row);
      }
      //if it failed show it.
      else
      {
        showTableRow(row);
        viewableCounter++;
      }
    }
    else if(hideUnrunNode.checked)
    {
      hideTableRow(row);
    }
    else
    {
      showTableRow(row);
      viewableCounter++;
    }
  }
  if((viewableCounter>0)&&(unitTests[name].tableExpanded))
  {
    displayTests(name);
  }
  else
  {
    hideTests(name);
  }
  unitTests[name].tableViewable=viewableCounter>0;

}

function showTableRow(row)
{
  row.style.display="";
}
function hideTableRow(row)
{
  row.style.display="none";
}
function expandAllResults()
{
  for(var name in unitTests)
  {
    expandTestSet(name);
  }
}
function collapseAllResults()
{
  for(var name in unitTests)
  {
    collapseTestSet(name);
  }
}
function expandTestSet(name)
{
  unitTests[name].expandIcon.childNodes[0].nodeValue="\u25b2";
  //this.childNodes[0].src="images/red-collapse.gif";
  unitTests[name].expandIcon.title="collapse";
  unitTests[name].tableExpanded=true;
  updateTestSetVisibility(name);

}
function collapseTestSet(name)
{
  unitTests[name].expandIcon.childNodes[0].nodeValue="\u25bc";
  unitTests[name].expandIcon.title="expand";
  unitTests[name].tableExpanded=false;
  hideTests(name);
}

//This shows the summary of all tests
function createShowTestsTable()
{
  var table=$n("table"),
      thead,
      headerRow,
      i,
      unitTestGroupName,
      cell,
      headingTexts,
      tableCellIds,
      tests,
      tbody,
      summaryRow,
      detailedRow,
      textVal,
      href,
      downArrowDiv,
      div,
      text,
      altClass;

  headingTexts=["Test Set","Tests","Successes","Failures"];
  tableCellIds=["testName","testCount","successCount","failCount"];

  table.className="test_table";

  //create the header
  thead = $n("thead");
  table.appendChild(thead);  
  
  headerRow = $n("tr");
  thead.appendChild(headerRow);
  for(i=0;i<4;i++)
  {
    cell = $n("th");
    cell.className="test_th";
    cell.appendChild(document.createTextNode(headingTexts[i]));
    headerRow.appendChild(cell);
  }
  
  //creates the body
  for(unitTestGroupName in unitTests)
  {
    tests = unitTests[unitTestGroupName].tests;
    tbody = $n("tbody");
    table.appendChild(tbody);
  
    //create the summary
    summaryRow = $n("tr");
    tbody.appendChild(summaryRow);

    //TODO: do this on the tbody instead
    altClass = "tr" + table.tBodies.length%2;
    summaryRow.className = altClass;
    
    //create each cell in a row
    for(i=0;i<4;i++)
    {
      cell = $n("td");
      summaryRow.appendChild(cell);
      cell.className = "test_td";
      //The first one's text value is the group name
      if(i===0)
      {
        textVal=unitTestGroupName;
      }
      //The second is the number of tests
      else if(i===1)
      {
        textVal=tests.length;
      }
      //All others are -s
      else
      {
        textVal="-";
      }
      text = document.createTextNode(textVal);
      //The first one needs the expand/collapse thing and the title,
      //The others are all simple
      if(i===0)
      {
        //var downArrow = $n("img");
        //downArrow.src="images/red-expand.gif"
        
        downArrowDiv = $n("span");
        downArrowDiv.title="expand";
        downArrowDiv.className="expandcollapse";

        downArrowDiv.appendChild(document.createTextNode("\u25bc"));
        downArrowDiv.down=true;
        downArrowDiv.onclick=
        function(e,name)
        {
          if(this.down)
          {
            expandTestSet(name);
          }
          else
          {
            collapseTestSet(name);
          }          
          this.down=!this.down;
        }.bindAsEventListener(downArrowDiv,unitTestGroupName);

        unitTests[unitTestGroupName].tableExpanded=false;
        unitTests[unitTestGroupName].expandIcon=downArrowDiv;
        cell.appendChild(downArrowDiv);
        
        href = $n("a");
        href.href="#";
        href.className="testSetRunner";
        href.onclick=runTestSet.bind(this,unitTestGroupName);
        href.appendChild(text);
        cell.appendChild(href);
      }
      else
      {
        div = $n("span");
        div.id=unitTestGroupName+tableCellIds[i];
        div.appendChild(text);
        cell.appendChild(div);
      }
    }
    
    //create the detailed display
    detailedRow = $n("tr");
    tbody.appendChild(detailedRow);

    cell = $n("td");
    cell.className="innerTests_td " + altClass;
    detailedRow.appendChild(cell);
    cell.colSpan=4;
    div = $n("div");
    unitTests[unitTestGroupName].viewer = 
      createDisplayTestSetTable(unitTestGroupName);
    div.appendChild(unitTests[unitTestGroupName].viewer);
    unitTests[unitTestGroupName].viewer.style.display="none";
    cell.appendChild(div);
  }
  return table;
}

//Creates the detailed analysis of each test case
function createDisplayTestSetTable(name)
{
  var table,
      thead,
      classes,
      innerTexts,
      i,j,
      row,
      cell,
      div,text,href;

  table=$n("table");  
  table.className="innerTests_table";

  classes=["code_heading","result_heading","expected_heading","pass_heading"];
  innerTexts=["Code","Result","Expected","Pass"];
  
  for(i=0;i<4;i++)
  {
    cell = $n("col");
    table.appendChild(cell);
  }

  thead = $n("thead");
  table.appendChild(thead);  
  
  row = $n("tr");
  thead.appendChild(row);
  for(i=0;i<4;i++)
  {
    cell = $n("th");
    cell.className="test_th";
    div = $n("div");
    div.className=classes[i];
    text = document.createTextNode(innerTexts[i]);
    div.appendChild(text);
    cell.appendChild(div);
    row.appendChild(cell);
  }

  var tBody = $n("tbody");
  table.appendChild(tBody);
  
  var ids=["code.","result.","expected.","pass."];
    
  for (i = 0; i < unitTests[name].tests.length; i++)
  {
    //if this row has not yet been created
    if(tBody.rows.length<=i)
    {
      row = $n("tr");
      tBody.appendChild(row);
    }
    else
    {
      row = tBody.rows[i+1];
    }
    clearChildren(row,"childNodes");
    row.className = "tr" + i%2;
    row.id = name + "row."+ i;

    for(j=0;j<ids.length;j++)
    {
      cell = $n("td");
      row.appendChild(cell);
      cell.className = "test_td";

      //Don't change this line without changing the id in postResults()
      cell.id = name+ids[j]+i;
      if(j===0)
      {
        div = $n("div");
        div.className ="code_cell";
        href = $n("a");
        href.href="#";
        href.onclick=runTest.bind(this,name,i);
        text = document.createTextNode(unitTests[name].tests[i].code);
        href.appendChild(text);
        div.appendChild(href);
        cell.appendChild(div);
      }
      row.appendChild(cell);
    }
  }
  return table;
}

//Show a detail table
function displayTests(name)
{
  unitTests[name].viewer.style.display="";
}

//Hide a detail table
function hideTests(name)
{
  unitTests[name].viewer.style.display="none";
}

//Runs all the tests
function runAllTests()
{
  for(var name in unitTests)
  {
    runTestSet(name);
  }
}

//Runs all the tests for a specific set
function runTestSet(name)
{
  var i;
  if (maxRequestNode.value < 1 || maxRequestNode.value > 99)
  {
    alert("Max requests should be between 1 and 99");
    return;
  }
  JSONRpcClient.max_req_active = maxRequestNode.value;

  clearResultSet(name);
  if (profileNode.checked)
  {
    tests_start = new Date();
  }
  if (asyncNode.checked)
  {
    JSONRpcClient.profile_async = profileNode.checked;
    cb = [];
    for (i = 0; i < unitTests[name].tests.length; i++)
    {
      runTestAsync(name,i);
    }
  }
  else
  {
    for (i = 0; i < unitTests[name].tests.length; i++)
    {
      runTestSync(name,i);
    }
  }
}

//Runs a test and determines which mode (sync/async) to run it in.
//Also looks after profiling
function runTest(name,i)
{
  clearResult(name,i);
  if (profileNode.checked)
  {
    //Global
    tests_start = new Date();
  }
  unitTests[name].tests[i].pass=false;
  unitTests[name].tests[i].completed=false;
  unitTests[name].tests[i].running=true;
  if (asyncNode.checked)
  {
    JSONRpcClient.profile_async = profileNode.checked;
    cb = [];
    runTestAsync(name,i);
  }
  else
  {
    runTestSync(name,i);
  }
}

//This is the callback function used with async tests
function testAsyncCB(name,i)
{
  return function (result, e, profile)
  {
    postResults(name,i, result, e, profile);
  };
}

//Run a test in async mode
function runTestAsync(name,i)
{
  var cb,code,str;
  try
  {
    // insert post results callback into first argument and submit test
    cb = testAsyncCB(name,i);
    //If it contains specific code to do the async calls then use this
    if(unitTests[name].tests[i].asyncCode)
    {
      code=unitTests[name].tests[i].asyncCode;
    }
    //Otherwise find every method call, ie: "()" and put cb in it.
    else
    {
      code = unitTests[name].tests[i].code;
      code = code.replace(/\(([^\)])/, "(cb, $1");
      code = code.replace(/\(\)/, "(cb)");
    }
    // run the test
    eval(code);
  }
  catch (e)
  {
    testAsyncCB(name,i)(null,e,false);
  }
}

//Runs a test in sync mode
function runTestSync(name,i)
{
  var result;
  var exception;
  var profile;
  if (profileNode.checked)
  {
    profile = {};
    profile.submit = profile.start = new Date();
  }
  try
  {
    eval("result = " + unitTests[name].tests[i].code);
  }
  catch (e)
  {
    exception = e;
  }
  if (profileNode.checked)
  {
    profile.end = profile.dispatch = new Date();
  }
  postResults(name,i, result, exception, profile);
}

/**
 * Displays the result of a test. Pass or Fail is calculated here.
 *
 * @param name the name of the test set
 * @param i the index of the test within the test set
 * @param result the string containing the result of the test
 * @param e any exception thrown when making the result
 * @param profile boolean saying whether profiling data should be shown
 */ 
function postResults(name,i, result, e, profile)
{
  var nodes=[
       document.getElementById(name+"result." + i),
       document.getElementById(name+"expected." + i),
       document.getElementById(name+"pass." + i)
      ],
      resultText,
      pass = false,
      actualResultText;
  
  if (e)
  {
    if (e.message)
    {
      resultText = e.message;
    }
    else
    {
      resultText = e.toString();
    }
    if (unitTests[name].tests[i].exception)
    {
      try
      {
        eval("pass = " + unitTests[name].tests[i].test);
      }
      catch(e)
      {
      }
    }
  }
  else
  {
    if (typeof result == "object")
    {
      var tmp = toJSON(result);
      var done={};
      var toString=function(o)
      {
        var str,x;
        if (typeof o == "object")
        {
          if(done[o])
          {
            return "circRef";
          }
          done[o]="";
          if(o.constructor === Array)
          {
            str="[";
            for(x in o)
            {
              str+=toString(o[x])+", ";
            }  
            str+="]";
          }
          else
          {
            str="{";
            for(x in o)
            {
              str+=toString(x)+": "+toString(o[x])+", ";
            }  
            str+="}";
          }
          return str;
          
        }
        else
        {
          return o.toString();
        }
      };
      resultText= toString(tmp);
    }
    else
    {
      resultText = result;
    }
    try
    {
      eval("pass = " + unitTests[name].tests[i].test);
    }
    catch(e)
    {
      var tmp="";
      for(var aa in e)
      {
        tmp+=aa+" "+e[aa].toString()+"\t";
      }
      resultText=tmp;
    }
  }
  if (profile)
  {
    actualResultText="submit=" + (profile.submit - tests_start) +
               ", start=" + (profile.start - tests_start) +
               ", end=" + (profile.end - tests_start) +
               ", dispatch=" + (profile.dispatch - tests_start) +
               " (rtt=" + (profile.end - profile.start)+")";
  }
  else
  {
    actualResultText=resultText;
  }
  var testValues = [actualResultText,unitTests[name].tests[i].test,(pass?"pass":"FAIL")];
  var classes = ["result_cell","result_cell",(pass?"pass_cell":"fail_cell")];

  
  unitTests[name].tests[i].pass=pass;
  unitTests[name].tests[i].completed=true;
  unitTests[name].tests[i].running=false;

  updateTestSetVisibility(name);

  for(var j=0;j<nodes.length;j++)
  {
    clearChildren(nodes[j],"childNodes");
    nodes[j].style.display="";
    var div = $n("div");
    div.className = classes[j];
    div.appendChild(document.createTextNode(testValues[j]));
    nodes[j].appendChild(div);
    //nodes[j].appendChild(document.createTextNode(testValues[j]));
  }
  
  
  //Update the global success/fail count for this test set
  var successCount=0;
  var failCount=0;
  for(j=0;j<unitTests[name].tests.length;j++)
  {
    //Only count it if the test is not running and has been completed
    if((!unitTests[name].tests[j].running) && (unitTests[name].tests[j].completed))
    {
      if(unitTests[name].tests[j].pass)
      {
        successCount++;
      }
      else
      {
        failCount++;
      }
    }
  }
  
  var successDiv=document.getElementById(name+"successCount");
  clearChildren(successDiv,"childNodes");
  successDiv.appendChild(document.createTextNode(successCount));
  var failDiv=document.getElementById(name+"failCount");
  clearChildren(failDiv,"childNodes");
  failDiv.appendChild(document.createTextNode(failCount));
}

//Clears all displayed test results
function clearAllResults()
{
  var tests=[];
  for(var name in unitTests)
  {
    clearResultSet(name);
  }
  updateAllTestsVisibility();
}

//clears all the posted results for a set of tests
function clearResultSet(name)
{  
  var successDiv=document.getElementById(name+"successCount");
  clearChildren(successDiv,"childNodes");
  successDiv.appendChild(document.createTextNode("-"));
  var failDiv=document.getElementById(name+"failCount");
  clearChildren(failDiv,"childNodes");
  failDiv.appendChild(document.createTextNode("-"));
  for(var i =0;i< unitTests[name].tests.length;i++)
  {
    clearResult(name,i);
  }
}

//Clear the result for the ith test in the test set given by name
function clearResult(name,i)
{
  var j,nodes = [
    document.getElementById(name+"result." + i),
    document.getElementById(name+"expected." + i),
    document.getElementById(name+"pass." + i)
  ];
  
  unitTests[name].tests[i].completed=false;
  unitTests[name].tests[i].running=false;

  for(j=0;j<nodes.length;j++)
  {
    clearChildren(nodes[j],"childNodes");
  }
}
