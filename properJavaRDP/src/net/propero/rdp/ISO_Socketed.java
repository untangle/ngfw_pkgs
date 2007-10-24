/* ISO_Socketed.java
 * Component: ProperJavaRDP
 * 
 * Revision: $Revision: 1.7 $
 * Author: $Author: telliott $
 * Date: $Date: 2005/09/27 14:15:39 $
 *
 * Copyright (c) 2005 Propero Limited
 *
 * This file was modified by Untangle, Inc. in 2007.
 * These changes are Copyright (c) 2007 Untangle, Inc.
 *
 * Purpose: Java 1.4 specific extension of ISO class
 */
// Created on 05-Aug-2003

package net.propero.rdp;

import java.io.*;
import java.net.*;
import net.propero.rdp.crypto.CryptoException;


public abstract class ISO_Socketed extends ISO {

    protected Socket rdpsock=null;

    protected void doSocketConnect(InetAddress host, int port) throws IOException {
        this.rdpsock = new Socket(host,port);
    }	

    public void connect(InetAddress host, int port) throws IOException, RdesktopException, OrderException, CryptoException {
	int[] code = new int[1];
	doSocketConnect(host,port);
	rdpsock.setTcpNoDelay(Options.low_latency);
	// this.in = new InputStreamReader(rdpsock.getInputStream());
        this.in = new DataInputStream(new BufferedInputStream(rdpsock.getInputStream()));
	this.out= new DataOutputStream(new BufferedOutputStream(rdpsock.getOutputStream()));
	send_connection_request();
	
	receiveMessage(code);
	if (code[0] != CONNECTION_CONFIRM) {
	    throw new RdesktopException("Expected CC got:" + Integer.toHexString(code[0]).toUpperCase());
	}

	/*if(Options.use_ssl){
          try {
          rdpsock = this.negotiateSSL(rdpsock);
          this.in = new DataInputStream(rdpsock.getInputStream());
          this.out= new DataOutputStream(rdpsock.getOutputStream());
          } catch (Exception e) {
          e.printStackTrace();
          throw new RdesktopException("SSL negotiation failed: " + e.getMessage());
          }
          }*/
	
    }

    public void disconnect() {
        super.disconnect();
	try { 
            if(rdpsock!=null) rdpsock.close();
        } catch (IOException x) { }
        rdpsock = null;
    }
}
