/* ISO_Portalaed.java
 *
 */

package net.propero.rdp;

import java.io.*;
import java.net.*;
import java.util.StringTokenizer;
import javax.net.SocketFactory;
import javax.net.ssl.*;
import java.security.cert.X509Certificate;
import org.apache.log4j.Logger;
import net.propero.rdp.crypto.CryptoException;


public class ISO_Portaled extends ISO {

    static Logger logger = Logger.getLogger("net.propero.rdp");

    public static final String RDP_PROXY_PATH = "/proxy/forward";
    public static final String TARGET_HEADER = "Target";
    public static final String COOKIE_HEADER = "Cookie";

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
            initFactory();
            rdpsock = sslFactory.createSocket();
            InetSocketAddress isa = new InetSocketAddress(host, port);
            rdpsock.connect(isa, 5000);
            // rdpsock.setTcpNoDelay(Options.low_latency);
            // this.in = new InputStreamReader(rdpsock.getInputStream());
            this.out= new DataOutputStream(new BufferedOutputStream(rdpsock.getOutputStream()));
            this.in = new DataInputStream(new BufferedInputStream(rdpsock.getInputStream()));
            StringBuilder sb = new StringBuilder();
            sb.append("GET ").append(RDP_PROXY_PATH).append(" HTTP/1.0\r\n");
            sb.append("Host: ").append(host.getHostName()).append("\r\n");
            sb.append(TARGET_HEADER).append(": ").append(Options.target_header).append("\r\n");
            if (Options.cookie_header != null)
                sb.append(COOKIE_HEADER).append(": ").append(Options.cookie_header).append("\r\n");
            sb.append("\r\n");
            out.write(sb.toString().getBytes());
            out.flush();
            boolean good = false;
            String statusLine = in.readLine();
            StringTokenizer st = new StringTokenizer(statusLine);
            if (st.hasMoreTokens()) {
                st.nextToken(); // HTTP/1.X
                if (st.hasMoreTokens()) {
                    String status = st.nextToken();
                    if (status.equals("200")) {
                        // Read until header done.
                        String line = in.readLine();
                        while (line != null && line.length() > 0)
                            line = in.readLine();
                        if (line != null)
                            good = true;
                    }
                }
            }
            if (!good)
                throw new IOException("Bad response from server: " + statusLine);
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
}
