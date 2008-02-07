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

package org.jabsorb.reflect;

import java.util.HashMap;

/**
 * Information on the public methods of a class as reflected from the Class
 * itself. This is produced by the ClassAnalyzer and used in the JSONRPCBridge
 * for resolving classes and methods to invoke through json-rpc.
 */
public class ClassData
{
  /**
   * The class that this ClassData maps.
   */
  protected Class clazz;

  /**
   * Map of public instance methods. Key is a MethodKey object, value is either
   * a Method or a Method[].
   */
  protected HashMap methodMap;

  /**
   * Map of public static methods. Key is a MethodKey object, value is either a
   * Method or a Method[].
   */
  protected HashMap staticMethodMap;

  /**
   * Get the class that this ClassData maps.
   * 
   * @return the class that this ClassData maps.
   */
  public Class getClazz()
  {
    return clazz;
  }

  /**
   * Get the Map of public non-static methods that can be invoked for the class.
   * The keys of the Map will be MethodKey objects and the values will be either
   * a Method object, or an array of Method objects, if there is more than one
   * possible method that can be invoked matching the MethodKey.
   * 
   * @return Map of public instance methods which can be invoked for the class.
   *         this ClassData.
   */
  public HashMap getMethodMap()
  {
    return methodMap;
  }

  /**
   * Get the Map of public static methods that can be invoked for the class. The
   * key of the Map is a MethodKey object and the value is either a Method
   * object, or an array of Method objects (if there is more than one possible
   * method that can be invoked matching the MethodKey.)
   * 
   * @return Map of static methods that can be invoked for the class.
   */
  public HashMap getStaticMethodMap()
  {
    return staticMethodMap;
  }
}
