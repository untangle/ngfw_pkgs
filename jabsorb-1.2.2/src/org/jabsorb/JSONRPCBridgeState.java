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

package org.jabsorb;

import java.io.Serializable;
import java.util.HashMap;
import java.util.HashSet;

import org.jabsorb.serializer.Serializer;
import org.jabsorb.serializer.impl.ReferenceSerializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Contains state information related to a JSONRPCBridge instance. This state
 * information includes exported classes, objects and references.
 */
public class JSONRPCBridgeState implements Serializable
{
  /**
   * Unique serialisation id.
   */
  private final static long serialVersionUID = 2;

  /**
   * The logger for this class
   */
  private final static Logger log = LoggerFactory
      .getLogger(JSONRPCBridgeState.class);

  /**
   * bridge this state information is associated with
   */
  private JSONRPCBridge bridge;

  /**
   * key "exported class name", val Class
   */
  private HashMap classMap = new HashMap();

  /**
   * key "exported instance name", val ObjectInstance
   */
  private HashMap objectMap = new HashMap();

  /**
   * key Integer hashcode, object held as reference
   */
  private HashMap referenceMap = null;

  /**
   * ReferenceSerializer if enabled
   */
  private Serializer referenceSerializer = null;

  /**
   * key clazz, classes that should be returned as References
   */
  private HashSet referenceSet = null;

  /**
   * key clazz, classes that should be returned as CallableReferences
   */
  private HashSet callableReferenceSet = null;

  /**
   * Creates a new JSONRPCBridgeState
   * 
   * @param bridge The bridge this state is for
   */
  public JSONRPCBridgeState(JSONRPCBridge bridge)
  {
    this.bridge = bridge;
  }

  /**
   * Gets the classes that have been registed as callable references.
   * 
   * @return key clazz, classes that should be returned as CallableReferences
   */
  public HashSet getCallableReferenceSet()
  {
    return callableReferenceSet;
  }

  /**
   * Sets the internal callable reference set.
   * 
   * @param callableReferenceSet the set to set.
   * 
   * TODO: Is this really good coding practice?
   */
  public void setCallableReferenceSet(HashSet callableReferenceSet)
  {
    this.callableReferenceSet = callableReferenceSet;
  }

  /**
   * Gets the registered classes
   * 
   * @return key "exported class name", val Class
   */
  public HashMap getClassMap()
  {
    return classMap;
  }

  /**
   * Sets the class map
   * 
   * @param classMap The class map to set.
   * 
   * TODO: Again, dodgy coding practice!
   */
  public void setClassMap(HashMap classMap)
  {
    this.classMap = classMap;
  }

  /**
   * Gets the known objects
   * 
   * @return key "exported instance name", val ObjectInstance
   */
  public HashMap getObjectMap()
  {
    return objectMap;
  }

  /**
   * Sets the object map
   * 
   * @param objectMap The object map to set.
   * 
   * TODO: Again, dodgy coding practice!
   */
  public void setObjectMap(HashMap objectMap)
  {
    this.objectMap = objectMap;
  }

  /**
   * Gets the known references
   * 
   * @return key Integer hashcode, object held as reference
   */
  public HashMap getReferenceMap()
  {
    return referenceMap;
  }

  /**
   * Sets the reference map
   * 
   * @param referenceMap The reference map to set.
   * 
   * TODO: Again, dodgy coding practice!
   */
  public void setReferenceMap(HashMap referenceMap)
  {
    this.referenceMap = referenceMap;
  }

  /**
   * Gets the serialiser for references
   * 
   * @return The reference serialiser
   */
  public Serializer getReferenceSerializer()
  {
    return referenceSerializer;
  }

  /**
   * Sets the reference serialiser
   * 
   * @param referenceSerializer The referenceSerialiser to set.
   * 
   * TODO: Again, dodgy coding practice!
   */
  public void setReferenceSerializer(Serializer referenceSerializer)
  {
    this.referenceSerializer = referenceSerializer;
  }

  /**
   * Gets the reference set
   * 
   * @return key clazz, classes that should be returned as References
   */
  public HashSet getReferenceSet()
  {
    return referenceSet;
  }

  /**
   * Sets the referenceset
   * 
   * @param referenceSet The reference set to set
   * 
   * TODO: Again, dodgy coding practice!
   */
  public void setReferenceSet(HashSet referenceSet)
  {
    this.referenceSet = referenceSet;
  }

  /**
   * Allows references to be used on the bridge
   * 
   * @throws Exception If a serialiser has already been registered for
   *           CallableReferences
   */
  public synchronized void enableReferences() throws Exception
  {
    // TODO: why have setters for these when they are all created here?
    if (referenceSerializer == null)
    {
      referenceSerializer = new ReferenceSerializer(bridge);
      bridge.registerSerializer(referenceSerializer);
      log.info("enabled references on this bridge");
    }
    if (referenceMap == null)
    {
      referenceMap = new HashMap();
    }
    if (referenceSet == null)
    {
      referenceSet = new HashSet();
    }
    if (callableReferenceSet == null)
    {
      callableReferenceSet = new HashSet();
    }
  }
}