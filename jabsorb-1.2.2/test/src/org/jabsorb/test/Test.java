/*
 * jabsorb - a Java to JavaScript Advanced Object Request Broker
 * http://www.jabsorb.org
 *
 * Copyright 2007 The jabsorb team
 *
 * based on original code from
 * JSON-RPC-Java - a JSON-RPC to Java Bridge with dynamic invocation
 *
 * Copyright Metaparadigm Pte. Ltd. 2004.
 * Michael Clark <michael@metaparadigm.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

package org.jabsorb.test;

import java.io.Serializable;
import java.lang.reflect.AccessibleObject;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Hashtable;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;
import java.util.Vector;

import javax.servlet.http.HttpServletRequest;

import org.jabsorb.JSONRPCBridge;
import org.jabsorb.callback.InvocationCallback;
import org.json.JSONObject;

/**
 * Server side unit tests, used by unit.jsp / unit.js.
 */
public class Test implements Serializable, ITest
{
  
  
  private final static long serialVersionUID = 2;

  // Void test

  public void voidFunction()
  {
  }

  // Exception tests

  public static void throwException() throws Exception
  {
    throw new Exception("test exception");
  }

  // Overload tests

  public String[] echo(String strings[])
  {
    return strings;
  }

  public int echo(int i)
  {
    return i;
  }

  public int[] echo(int i[])
  {
    return i;
  }

  public String echo(String message)
  {
    return message;
  }

  // Type tests

  public List echoList(List l)
  {
    return l;
  }

  public byte[] echoByteArray(byte ba[])
  {
    return ba;
  }

  public char[] echoCharArray(char ca[])
  {
    return ca;
  }

  public char echoChar(char c)
  {
    return c;
  }

  public boolean echoBoolean(boolean b)
  {
    return b;
  }

  public boolean[] echoBooleanArray(boolean ba[])
  {
    return ba;
  }

  public Integer[] echoIntegerArray(Integer i[])
  {
    return i;
  }

  public Integer echoIntegerObject(Integer i)
  {
    return i;
  }

  public Long echoLongObject(Long l)
  {
    return l;
  }

  public Float echoFloatObject(Float f)
  {
    return f;
  }

  public Double echoDoubleObject(Double d)
  {
    return d;
  }

  public Date echoDateObject(Date d)
  {
    return d;
  }

  public Object echoObject(Object o)
  {
    return o;
  }

  public Object echoObjectArray(Object[] o)
  {
    return o;
  }

  public JSONObject echoRawJSON(JSONObject rawObject)
  {
    return rawObject;
  }

  // Container tests

  public int[] anArray()
  {
    int arr[] = new int[10];
    for (int i = 0; i < 10; i++)
    {
      arr[i] = i;
    }
    return arr;
  }

  public ArrayList anArrayList()
  {
    ArrayList al = new ArrayList();
    for (int i = 10; i < 20; i++)
    {
      al.add(new Integer(i));
    }
    return al;
  }

  public Vector aVector()
  {
    Vector v = new Vector();
    for (int i = 20; i < 30; i++)
    {
      v.add(new Integer(i));
    }
    return v;
  }

  public List aList()
  {
    List l = new Vector();
    for (int i = 20; i < 30; i++)
    {
      l.add(new Integer(i));
    }
    return l;
  }

  public Set aSet()
  {
    Set s = new HashSet();
    for (int i = 0; i < 5; i++)
    {
      s.add(new Integer(i));
    }
    return s;
  }

  public Hashtable aHashtable()
  {
    Hashtable ht = new Hashtable();
    for (int i = 0; i < 3; i++)
    {
      Wiggle w = new Wiggle();
      w.setFoo("foo " + i);
      w.setBar(i);
      ht.put(new Integer(i), w);
    }
    return ht;
  }

  // circular reference tests

  public BeanA aBean()
  {
    BeanA beanA = new BeanA();
    BeanB beanB = new BeanB();

    beanB.setBeanA(beanA);
    beanB.setId(beanB.hashCode());
    beanA.setBeanB(beanB);
    beanA.setId(beanA.hashCode());

    return beanA;
  }

  public Map aCircRefMap()
  {
    Map m = new HashMap();
    m.put("me",m);
    return m;
  }
  
  public List aCircRefList()
  {
    ArrayList list = new ArrayList();
    list.add(new Integer(0));
    Integer one = new Integer(1);
    list.add(one);
    Integer two = new Integer(2);
    list.add(two);

    Map m = new HashMap();
    m.put(new Integer(0), "zero");
    m.put(one, "one");
    m.put(two, "two");
    m.put("buckle_my_shoe",list);


    BeanA beanA = new BeanA();
    BeanB beanB = new BeanB();
    beanB.setBeanA(beanA);
    beanA.setBeanB(beanB);

    m.put("aBean",beanA);

    list.add(beanB);
    list.add(m);
    return list;
  }

  /**
   * Test more than one duplicate, to make sure the fixups they generate
   * all refer to the same object 
   * @return a List with some duplicates.
   */
  public List aDupDup()
  {
    List list = new ArrayList();


    BeanA a = new BeanA();
    BeanB b = new BeanB();

    BeanA c = new BeanA();
    BeanB d = new BeanB();

    a.setBeanB(d);
    b.setBeanA(c);

    list.add(a);
    list.add(b);
    list.add(c);
    list.add(d);

    return list;
  }

  /**
   * Another duplicate with substantial savings to be gained by fixing it up
   * @return a List with duplicates.
   */
  public List aDupDupDup()
  {
    Map m = new HashMap();
    m.put("drink","soda");
    m.put("tree","oak");
    m.put("planet","jupiter");
    m.put("art","painting");
    m.put("animal","tiger");
    List list = new ArrayList();

    list.add(m);
    list.add(m);
    list.add(m);
    list.add(m);

    Map m2 = new TreeMap();
    m2.put("map",m);
    m2.put("dup",m);
    m2.put("copy",m);
    m2.put("ditto",m);
    m2.put("extra",m);

    list.add(m2);
    return list;
  }
  
  /**
   * Test of duplicate Strings
   * @return a List with 3 duplicate Strings.
   */
  public List aStringListDup()
  {
    List list = new ArrayList();

    String dup = "Supercalifragilisticexpialidocious";
    list.add(dup);
    list.add(dup);
    list.add(dup);
    return list;
  }

  /**
   * Test an array of 3 duplicate Strings.
   * 
   * @return an array of 3 duplicate Strings.
   */
  public String[] aStringArrayDup()
  {
    String[] arr = new String[3];
    String dup = "Supercalifragilisticexpialidocious";
    arr[0] = dup;
    arr[1] = dup;
    arr[2] = dup;
    return arr;
  }
  
  /**
   * Test an array of 3 duplicate Beans.
   * 
   * @return an array of 3 duplicate Beans.
   */
  public BeanA[] aBeanArrayDup()
  {
    BeanB b = new BeanB();
    BeanA a = new BeanA();
    a.setBeanB(b);
    BeanA[] arr = new BeanA[3];
    arr[0] = a;
    arr[1] = a;
    arr[2] = a;
    return arr;
  }

  /**
   * Return a List that has several Strings and a few nulls.
   * We want make sure that the null objects don't get fixed up (as duplicates...)
   * @return a List that has several Strings and a few nulls.
   */
  public List listNull()
  {
    List l = new ArrayList();
    l.add("one");
    l.add("two");
    l.add(null);
    l.add("my");
    l.add("shoe");
    l.add(null);
    l.add(null);
    l.add(null);
    return l;
  }

  // Misc tests

  public String[] twice(String string)
  {
    return new String[]{string, string};
  }

  public String concat(String msg1, String msg2)
  {
    return msg1 + " and " + msg2;
  }

  // Bean tests

  static public class Wiggle implements Serializable
  {

    private final static long serialVersionUID = 2;

    private String foo;

    private int bar;

    public Wiggle()
    {
    }

    public Wiggle(int i)
    {
      bar = i;
      foo = "foo";
    }

    public String getFoo()
    {
      return foo;
    }

    public void setFoo(String foo)
    {
      this.foo = foo;
    }

    public int getBar()
    {
      return bar;
    }

    public void setBar(int bar)
    {
      this.bar = bar;
    }

    public String toString()
    {
      return "wiggle " + foo + " and " + bar;
    }
  }

  static public class Waggle implements Serializable
  {

    private final static long serialVersionUID = 2;

    private int baz;

    private String bang;

    Integer bork;

    public Waggle()
    {
    }

    public Waggle(int i)
    {
      baz = i;
      bang = "!";
    }

    public int getBaz()
    {
      return baz;
    }

    public void setBaz(int baz)
    {
      this.baz = baz;
    }

    public String getBang()
    {
      return bang;
    }

    public void setBang(String bang)
    {
      this.bang = bang;
    }

    public Integer getBork()
    {
      return bork;
    }

    public void setBork(Integer bork)
    {
      this.bork = bork;
    }

    public String toString()
    {
      return "waggle " + baz + " and " + bang;
    }
  }

  public Wiggle echo(Wiggle wiggle)
  {
    return wiggle;
  }

  public Waggle echo(Waggle waggle)
  {
    return waggle;
  }

  public ArrayList aWiggleArrayList(int numWiggles)
  {
    ArrayList al = new ArrayList();
    for (int i = 0; i < numWiggles; i++)
    {
      al.add(new Wiggle(i));
    }
    return al;
  }

  public ArrayList aWaggleArrayList(int numWaggles)
  {
    ArrayList al = new ArrayList();
    for (int i = 0; i < numWaggles; i++)
    {
      al.add(new Waggle(i));
    }
    return al;
  }

  public String wigOrWag(ArrayList al)
  {
    Iterator i = al.iterator();
    StringBuffer buf = new StringBuffer();
    while (i.hasNext())
    {
      Object o = i.next();
      if (o instanceof Wiggle)
      {
        Wiggle w = (Wiggle) o;
        buf.append(w + " ");
      }
      else if (o instanceof Waggle)
      {
        Waggle w = (Waggle) o;
        buf.append(w + " ");
      }
      else
      {
        buf.append("unknown object ");
      }
    }
    return buf.toString();
  }

  // Reference Tests

  static public class RefTest implements Serializable
  {

    private final static long serialVersionUID = 2;

    private String s;

    public RefTest(String s)
    {
      this.s = s;
    }

    public String toString()
    {
      return s;
    }
  }

  static public class CallableRefTest implements Serializable, Comparable
  {

    private final static long serialVersionUID = 2;

    private static RefTest ref = new RefTest("a secret");
    
    public String ping()
    {
      return "ping pong";
    }

    public RefTest getRef()
    {
      return ref;
    }

    public String whatsInside(RefTest r)
    {
      return r.toString();
    }

    public int compareTo(Object arg0)
    {
      return System.identityHashCode(this)-System.identityHashCode(arg0);
    }
  }

  private static CallableRefTest callableRef = new CallableRefTest();

  public CallableRefTest getCallableRef()
  {
    return callableRef;
  }
  
  public Vector getCallableRefVector()
  {
    Vector v = new Vector();
    v.add(callableRef);
    v.add(callableRef);
    return v;
  }
  public Vector getCallableRefInnerVector()
  {
    Vector v1 = new Vector();
    Vector v = new Vector();
    v.add(callableRef);
    v.add(callableRef);
    v1.add(v);    
    return v1;
  }
  public Map getCallableRefMap()
  {
    Map m = new TreeMap();
    m.put("a",callableRef);
    m.put("b",callableRef);
    return m;
  }
  public Set getCallableRefSet()
  {
    Set s = new TreeSet();
    s.add(callableRef);
    return s;
  }
  // Callback tests

  public void setCallback(JSONRPCBridge bridge, boolean flag)
  {
    if (flag)
    {
      bridge.registerCallback(cb, HttpServletRequest.class);
    }
    else
    {
      bridge.unregisterCallback(cb, HttpServletRequest.class);
    }
  }

  public static InvocationCallback cb = new InvocationCallback()
  {

    private final static long serialVersionUID = 2;

    public void preInvoke(Object context, Object instance, Method m,
                          Object arguments[]) throws Exception
    {
      System.out.print("Test.preInvoke");
      if (instance != null)
      {
        System.out.print(" instance=" + instance);
      }
      System.out.print(" method=" + ((Method)m).getName());
      for (int i = 0; i < arguments.length; i++)
      {
        System.out.print(" arg[" + i + "]=" + arguments[i]);
      }
      System.out.println("");
    }

    public void postInvoke(Object context, Object instance, Method m,
                           Object result) throws Exception
    {
    }
  };
  
}
