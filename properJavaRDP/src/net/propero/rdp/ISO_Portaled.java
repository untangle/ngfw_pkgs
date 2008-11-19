/*
 * $HeadURL$
 * Copyright (c) 2003-2007 Untangle, Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License, version 2,
 * as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * AS-IS and WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE, TITLE, or
 * NONINFRINGEMENT.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
 */

package net.propero.rdp;

import java.io.*;
import java.net.*;
import java.security.cert.X509Certificate;
import java.util.StringTokenizer;
import javax.jnlp.*;
import javax.net.SocketFactory;
import javax.net.ssl.*;

import net.propero.rdp.crypto.CryptoException;
import org.apache.log4j.Logger;


public class ISO_Portaled extends ISO {

    static Logger logger = Logger.getLogger("net.propero.rdp");

    public static final String NONCE_HEADER = "X-Nonce";

    SocketFactory sslFactory;
    protected Socket rdpsock=null;

    protected void initFactory() throws IOException {
        try {
            SSLContext sc = null;
            // create a trust manager that does not validate certificate chains
            TrustManager[] trustAllCerts = new TrustManager[] { new X509TrustManager() {
                    public X509Certificate[] getAcceptedIssuers() {
                        return null;
                    }

                    public void checkClientTrusted(X509Certificate[] certs, String authType) {
                    }

                    public void checkServerTrusted(X509Certificate[] certs, String authType) {
                    }
                } };

            // install the all-trusting trust manager
            sc = SSLContext.getInstance("SSL");
            sc.init(null, trustAllCerts, new java.security.SecureRandom());
            sslFactory = (SSLSocketFactory)sc.getSocketFactory();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    protected void doSocketConnect(InetAddress host, int port) throws IOException {
        try {
            if (Options.target_header == null)
                throw new IOException("No target for rdp portal");
            else
                logger.debug("ISO_Portaled: " + Options.target_header);

            initFactory();
            rdpsock = sslFactory.createSocket();
            InetSocketAddress isa = new InetSocketAddress(host, port);
            rdpsock.connect(isa, 5000);
            rdpsock.setTcpNoDelay(Options.low_latency);
            // this.in = new InputStreamReader(rdpsock.getInputStream());
            OutputStream sockOut = rdpsock.getOutputStream();
            InputStream sockIn = rdpsock.getInputStream();
            DataInputStream din = new DataInputStream(sockIn);
            StringBuilder sb = new StringBuilder();

            String nonce_header = getNonce(Options.cookie_header,
                                           Options.pysid_cookie_header);

            sb.append("CONNECT ").append(Options.target_header).append(" HTTP/1.0\r\n");

            sb.append("Host: ").append(host.getHostName()).append("\r\n");
            sb.append(NONCE_HEADER).append(": ").append(nonce_header).append("\r\n");

            sb.append("\r\n");

            sockOut.write(sb.toString().getBytes());
            sockOut.flush();
            boolean good = false;
            String statusLine = din.readLine();
            StringTokenizer st = new StringTokenizer(statusLine);
            if (st.hasMoreTokens()) {
                st.nextToken(); // HTTP/1.X
                if (st.hasMoreTokens()) {
                    String status = st.nextToken();
                    if (status.equals("200")) {
                        // Read until header done.
                        String line = din.readLine();
                        while (line != null && line.length() > 0)
                            line = din.readLine();
                        if (line != null)
                            good = true;
                    }
                }
            }
            if (!good)
                throw new IOException("Bad response from server: " + statusLine);

            this.out= new DataOutputStream(sockOut);
            this.in = new DataInputStream(sockIn);
        } catch (IOException x) {
            logger.error("Unable to connect", x);
            rdpsock = null;
        }
        logger.info("connected!");
    }

    public void connect(InetAddress host, int port) throws IOException, RdesktopException, OrderException, CryptoException {
        int[] code = new int[1];
        doSocketConnect(host,port);
        send_connection_request();

        receiveMessage(code);
        if (code[0] != CONNECTION_CONFIRM) {
            logger.info("receive bad!");
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
        if (rdpsock!=null)
            try {
                rdpsock.close();
            } catch (IOException x) { }
        rdpsock = null;
    }

    private String getNonce(String javaCookie, String pythonCookie)
    {
        String nonce = null;

        try {
            BasicService bs = (BasicService)ServiceManager.lookup("javax.jnlp.BasicService");
            URL cb = bs.getCodeBase();
            URL nu = new URL(cb, "nonce");
            URLConnection nc = nu.openConnection();

            if (null != pythonCookie) {
                nc.setRequestProperty("Cookie", "pysid=" + pythonCookie);
            }

            if (null != javaCookie) {
                nc.setRequestProperty("Cookie", "JSESSIONIDSSO="
                                      + javaCookie);
            }

            InputStream is = null;
            try {
                is = nc.getInputStream();
                Reader isr = new InputStreamReader(is);
                BufferedReader br = new BufferedReader(isr);
                nonce = br.readLine().trim();
            } finally {
                if (null != is) {
                    is.close();
                }
            }
        } catch (IOException exn) {
            System.err.println("could not get nonce: " + exn);
        } catch (UnavailableServiceException exn) {
            System.err.println("could not get nonce: " + exn);
        }

        return nonce;
    }
}
