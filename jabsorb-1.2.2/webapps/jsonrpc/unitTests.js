// set up some objects for testing circular references and duplicates

// the simplest circular reference case
var circRef1 = {};
circRef1.circRef1 = circRef1;

// another simple circular reference
var aaa = {};
var bbb = {};
aaa.bbb=bbb;
bbb.aaa=aaa;

// a circular reference in an array
var circ3 = {};
circ3.arr=[3,1,4,1,circ3,9,2];

var circ3ArrLen = circ3.arr.length;

// an example of an object that has a lot of duplicates
var dup1 = {};

dup1.usa = {
  name:'USA',
  description:'United States of America',
  states:50
};

dup1.diana = {};
dup1.donald = {};
dup1.arthur = {};

dup1.diana.son = dup1.arthur;
dup1.diana.country = dup1.usa;
dup1.donald.son = dup1.arthur;
dup1.donald.country = dup1.usa;
dup1.arthur.mother = dup1.diana;
dup1.arthur.father = dup1.donald;
dup1.arthur.country = dup1.usa;
dup1.arthur.country.wow={};
dup1.arthur.country.wow.slick=dup1.arthur.country.wow;


// an example of an object that has a lot of duplicates and circular references both
var dup2 = {};

dup2.usa = {
  name:'USA',
  description:'United States of America',
  states:50
};

dup2.diana = {};
dup2.donald = {};
dup2.arthur = {};
dup2.paula = {};
dup2.larry = {};

dup2.diana.son = dup2.arthur;
dup2.diana.country = dup2.usa;
dup2.donald.son = dup2.arthur;
dup2.donald.country = dup2.usa;
dup2.arthur.mother = dup2.diana;
dup2.arthur.father = dup2.donald;
dup2.arthur.country = dup2.usa;
dup2.arthur.spouse = dup2.paula;
dup2.paula.spouse = dup2.arthur;
dup2.donald.spouse=dup2.diana;
dup2.diana.spouse=dup2.donald;
dup2.larry.friends=[dup2.arthur,dup2.paula,dup2.diana,dup2.donald,dup2.larry];
dup2.paula.friends=[dup2.arthur,dup2.larry,dup2.paula];

var circRefList =
{
  "list": [
    0,
    1,
    2,
    {
      "javaClass": "org.jabsorb.test.BeanB",
      "beanA": {
        "javaClass": "org.jabsorb.test.BeanA",
        "id": 0
      },
      "id": 0
    },
    {
      "javaClass": "java.util.HashMap",
      "map": {
        "2": "two",
        "0": "zero",
        "1": "one"
      }
    }
  ],
  "javaClass": "java.util.ArrayList"
};

circRefList.list[3].beanA.beanB = circRefList.list[3];
circRefList.list[4].map.buckle_my_shoe = circRefList;
circRefList.list[4].map.aBean = circRefList.list[3].beanA;

// the unit tests

var unitTests={
  "Circular References":
  {
    tests: 
    [
      // circular reference from server
      { code: 'jsonrpc.test.aBean()',
        test: 'result != null'
      },

      //server circ ref test of a Map
      { code: 'jsonrpc.test.aCircRefMap()',
        test: 'result.map.me===result'},

      //server circ ref test of a List generated on JS side
      { code: 'jsonrpc.test.echoObject(circRefList)',
        test: 'result.list[4].map.buckle_my_shoe===result'},

      //server circ ref test of an identical List generated on Java side
      { code: 'jsonrpc.test.aCircRefList()',
        test: 'result.list[4].map.buckle_my_shoe===result'},

      // circular references 1
      { code: 'jsonrpc.test.echoRawJSON({"field1": circRef1})',
        test: 'result.field1.circRef1 === result.field1.circRef1.circRef1'},

      // circular references 2
      { code: 'jsonrpc.test.echoRawJSON(aaa)',
        test: '(result.bbb.aaa===result)'},

      // circular references 3
      { code: 'jsonrpc.test.echoRawJSON({"field1": circ3})',
        test: 'result.field1.arr[4]===result.field1 && circ3ArrLen === result.field1.arr.length'},

      // duplicates test
      { code: 'jsonrpc.test.echoRawJSON({"field1": dup1})',
        test: 'result.field1.arthur.mother == result.field1.diana && result.field1.diana.son===result.field1.arthur'},

      // duplicates and circular references
      { code: 'jsonrpc.test.echoRawJSON(dup2)',
        test: 'result.arthur.mother===result.diana && result.diana.son===result.arthur'},

      // List of duplicate Strings
      { code: 'jsonrpc.test.aStringListDup()',
        test: 'result.list[0]===result.list[1] && result.list[1]===result.list[2]'},

      // Array of duplicate Strings
      { code: 'jsonrpc.test.aStringArrayDup()',
        test: 'result[0]===result[1] && result[1]===result[2]'},

      // Array of duplicate Beans
      { code: 'jsonrpc.test.aBeanArrayDup()',
        test: 'result[0]===result[1] && result[1]===result[2]'},

      // the following 3 tests don't really have a good way to test if they pass/fail (need server side support)
      // but they are in here in the hopes that this server side support will be added soon

      // duplicates from the server
      { code: 'jsonrpc.test.aDupDup()',
        test: 'true'},
  
      // more duplicates from the server
      { code: 'jsonrpc.test.aDupDupDup()',
        test: 'true'},

      //a list with some nulls in it
      { code: 'jsonrpc.test.listNull()',
        test: 'true'}
    ]
  },

  "Callable References":
  {
    tests:
    [
      { code:             'function(){ var callableRef = jsonrpc.test.getCallableRef(); return ({ oid:callableRef.objectID, ping:callableRef.ping(), refoid:callableRef.getRef().objectID, inside:callableRef.whatsInside(callableRef.getRef()) })}()',
        asyncCode: 'var __=function(){ var callableRef = jsonrpc.test.getCallableRef(); cb     ({ oid:callableRef.objectID, ping:callableRef.ping(), refoid:callableRef.getRef().objectID, inside:callableRef.whatsInside(callableRef.getRef()) })}()',
        test: 'result.ping == "ping pong" && result.inside =="a secret"'
      },
      { code:             'function(){ var callableRef = jsonrpc.test.getCallableRef(); var p = callableRef.ping();return({ping:p})}();',
        asyncCode: 'var __=function(){ var callableRef = jsonrpc.test.getCallableRef(); var p = callableRef.ping();cb    ({ping:p});}();',
        test: 'result.ping == "ping pong"'
      },
      { code: 'jsonrpc.test.getCallableRefVector();',
        test: '(result.list[0].ping() == "ping pong") && (result.list[1].ping() == "ping pong")'
      },
      { code: 'jsonrpc.test.getCallableRefInnerVector();',
        test: '(result.list[0].list[0].ping() == "ping pong") && (result.list[0].list[1].ping() == "ping pong")'
      },
      { code: 'jsonrpc.test.getCallableRefMap();',
        test: '(result.map["a"].ping() == "ping pong") && (result.map["b"].ping() == "ping pong")'
      },
      { code: 'jsonrpc.test.getCallableRefSet();',
        test: 'function(){for(a in result.set){if(result.set[a].ping() != "ping pong")return false;}return true;}() '
      }
    ]
  },
  
  "Primitives":
  {  
    tests:
    [
      { code: 'jsonrpc.test.voidFunction()',
        test: 'result == undefined'
      },
      { code: 'jsonrpc.test.echoChar("c")',
        test: 'result == "c"'
      },
      { code: 'jsonrpc.test.echo("")',
        test: 'result == ""'
      },
      { code: 'jsonrpc.test.echoIntegerObject(1234567890)',
        test: 'result == 1234567890'
      },
      { code: 'jsonrpc.test.echoLongObject(1099511627776)',
        test: 'result == 1099511627776'
      },
      { code: 'jsonrpc.test.echoFloatObject(3.3)',
        test: 'result == 3.3'
      },
      { code: 'jsonrpc.test.echoDoubleObject(9.9)',
        test: 'result == 9.9'
      },
      { code: 'jsonrpc.test.echoBoolean(true)',
        test: 'result == true'
      },
      { code: 'jsonrpc.test.echoBoolean(false)',
        test: 'result == false'
      }
    ]
  },
  
  "Objects":
  {  
    tests:
    [
      { code: 'jsonrpc.test.concat("a","b")',
        test: 'result == "a and b"'
      },
      { code: 'jsonrpc.test.aBean()',
        test: 'result != null'
      },
      { code: 'jsonrpc.test.echoObject({ "javaClass": "org.jabsorb.test.Test$Waggle", "bang": "foo", "baz": 9, "bork": 5 })',
        test: 'result.javaClass == "org.jabsorb.test.Test$Waggle" && result.bang =="foo" && result.baz == 9 && result.bork == 5'
      },
      { code: 'jsonrpc.test.echoRawJSON({ a: false})',
        test: 'result.a === false '
      },
      { code: 'jsonrpc.test.echoRawJSON({ a: ""})',
        test: 'result.a === "" '
      },
      { code: 'jsonrpc.test.echoRawJSON({ a: 0})',
        test: 'result.a === 0 '
      },
      { code: 'jsonrpc.test.echoObjectArray([{ "javaClass": "org.jabsorb.test.Test$Waggle", "bang": "foo", "baz": 9, "bork": 5 }])',
        test: 'result[0].javaClass == "org.jabsorb.test.Test$Waggle" && result[0].bang =="foo" && result[0].baz == 9 && result[0].bork == 5'
      },
      { code: 'jsonrpc.test.echoRawJSON({ "field1": "test" })',
        test: 'result.field1 == "test"'
      }
    ]
  },
  
  
  "Dates":
  {  
    tests:
    [
      { code: 'jsonrpc.test.echoDateObject(new Date(1121689294000))',
        test: 'result.javaClass == "java.util.Date" && result.time == 1121689294000'
      }
    ]
  },
  
  "Lists":
  {  
    tests:
    [
      { code: 'jsonrpc.test.echo([1,2,3])',
        test: 'result.length == 3 && result[0] == 1 && result[1] == 2 && result[2] == 3'
      },
      { code: 'jsonrpc.test.echo(["foo", "bar", "baz"])',
        test: 'result.length == 3 && result[0] == "foo" && result[1] == "bar" && result[2] == "baz"'
      },
      { code: 'jsonrpc.test.echo(["foo", null, "baz"])',
        test: 'result.length == 3 && result[0] == "foo" && result[1] == null && result[2] == "baz"'
      },
      { code: 'jsonrpc.test.echoList({"list":[20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "javaClass":"java.util.Vector"})',
        test: 'result.list.constructor == Array'
      },
      { code: 'jsonrpc.test.echoList({"list":[null, null, null], "javaClass":"java.util.Vector"})',
        test: 'result.list.constructor == Array'
      },
      { code: 'jsonrpc.test.echoIntegerArray([1234, 5678])',
        test: 'result[0] == 1234 && result[1] == 5678'
      },
      { code: 'jsonrpc.test.echoByteArray("testing 123")',
        test: 'result == "testing 123"'
      },
      { code: 'jsonrpc.test.echoCharArray("testing 456")',
        test: 'result == "testing 456"'
      },
      { code: 'jsonrpc.test.echoBooleanArray([true, false, true])',
        test: 'result.length == 3 && result[0] == true && result[1] == false && result[2] == true'
      },
      { code: 'jsonrpc.test.anArray()',
        test: 'result.constructor == Array'
      },
      { code: 'jsonrpc.test.anArrayList()',
        test: 'result.list.constructor == Array'
      },
      { code: 'jsonrpc.test.aVector()',
        test: 'result.list.constructor == Array'
      },
      { code: 'jsonrpc.test.aList()',
        test: 'result.list.constructor == Array'
      }
    ]
  },
  
  "Sets":
  {  
    tests:
    [
      { code: 'jsonrpc.test.aSet()',
        test: 'result.set.constructor == Object'
      }
    ]
  },
  
  "Maps":
  {  
    tests:
    [
      { code: 'jsonrpc.test.aHashtable()',
        test: 'result.map.constructor == Object'
      },
      { code: 'jsonrpc.test.echo({ bang: "foo", baz: 9 })',
        test: 'result.javaClass == "org.jabsorb.test.Test$Waggle" && result.bang =="foo" && result.baz == 9'
      },
      { code: 'jsonrpc.test.echo({ bang: "foo", baz: 9, bork: 5 })',
        test: 'result.javaClass == "org.jabsorb.test.Test$Waggle" && result.bang =="foo" && result.baz == 9'
      },
      { code: 'jsonrpc.test.echo({ bang: "foo", baz: 9, bork: null })',
        test: 'result.javaClass == "org.jabsorb.test.Test$Waggle" && result.bang =="foo" && result.baz == 9'
      },
      { code: 'jsonrpc.test.echo({ foo: "bang", bar: 11 })',
        test: 'result.javaClass == "org.jabsorb.test.Test$Wiggle" && result.foo =="bang" && result.bar == 11'
      }
    ]
  },
  "Exceptions":
  {  
    tests:
    [
      { code: 'jsonrpc.test.throwException()',
        test: 'e == "java.lang.Exception: test exception"',
        exception: true
      }
    ]
  },
  "Special Characters":
  {  
    tests:
    [
      { code: 'jsonrpc.test.echo("hello")',
        test: 'result == "hello"'
      },
      { code: 'jsonrpc.test.echo("\\"")',
        test: 'result ==         "\\""'
      },
      { code: 'jsonrpc.test.echo("\\\\")',
        test: 'result ==         "\\\\"'
      },
      { code: 'jsonrpc.test.echo("\\b")',
        test: 'result ==         "\\b"'
      },
      { code: 'jsonrpc.test.echo("\\t")',
        test: 'result ==         "\\t"'
      },
      { code: 'jsonrpc.test.echo("\\n")',
        test: 'result ==         "\\n"'
      },
      { code: 'jsonrpc.test.echo("\\f")',
        test: 'result ==         "\\f"'
      },
      { code: 'jsonrpc.test.echo("\\r")',
        test: 'result ==         "\\r"'
      },
      { code: 'jsonrpc.test.echo(1234)',
        test: 'result == 1234'
      },
      { code:      'jsonrpc.test.echoRawJSON({ "field1": "azAZ019!@#$^&*()_+-=\\|;,.<>/`~{}[]%" })',
        asyncCode: 'jsonrpc.test.echoRawJSON(cb,{ "field1": "azAZ019!@#$^&*()_+-=\\|;,.<>/`~{}[]%" })',
        test: 'result.field1 == "azAZ019!@#$^&*()_+-=\\|;,.<>/`~{}[]%"'
      }
    ]
  }
}