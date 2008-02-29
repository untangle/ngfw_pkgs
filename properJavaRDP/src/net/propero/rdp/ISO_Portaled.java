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
import java.util.StringTokenizer;
import javax.net.SocketFactory;
import javax.net.ssl.*;
import java.security.cert.X509Certificate;
import org.apache.log4j.Logger;
import net.propero.rdp.crypto.CryptoException;


public class ISO_Portaled extends ISO {

    static Logger logger = Logger.getLogger("net.propero.rdp");

    public static final String RDP_PROXY_PATH = "/proxy/forward";
    public static final String RPC_PROXY_PATH = "/rsaproxy/forward";
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
	    else
	 	logger.error("ISO_Portaled: " + Options.target_header);
	
            initFactory();
            rdpsock = sslFactory.createSocket();
            InetSocketAddress isa = new InetSocketAddress(host, port);
            rdpsock.connect(isa, 5000);
            // rdpsock.setTcpNoDelay(Options.low_latency);
            // this.in = new InputStreamReader(rdpsock.getInputStream());
            OutputStream sockOut = rdpsock.getOutputStream();
            InputStream sockIn = rdpsock.getInputStream();
            DataInputStream din = new DataInputStream(sockIn);
            StringBuilder sb = new StringBuilder();

            //sb.append("GET ").append(RDP_PROXY_PATH).append(" HTTP/1.1\r\n");
            sb.append("GET ").append(RPC_PROXY_PATH).append(" HTTP/1.1\r\n");

            sb.append("Host: ").append(host.getHostName()).append("\r\n");
            sb.append("Transfer-Encoding: chunked").append("\r\n");
            sb.append(TARGET_HEADER).append(": ").append(Options.target_header).append("\r\n");
            if (Options.cookie_header != null)
                sb.append(COOKIE_HEADER).append(": ").append("$Version=0; JSESSIONIDSSO=").append(Options.cookie_header).append("\r\n");
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

            this.out= new DataOutputStream(new ChunkedOutputStream(sockOut));
            this.in = new DataInputStream(new ChunkedInputStream(sockIn));
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

    
    class ChunkedInputStream extends InputStream {

        /** The data receiver that we're wrapping */
        private InputStream in;

        private char lineBuffer[];
    
        /** The chunk size */
        private int chunkSize;

        /** The current position within the current chunk */
        private int pos;

        /** True if we'are at the beginning of stream */
        private boolean bof = true;

        /** True if we've reached the end of stream */
        private boolean eof = false;

        /** True if this stream is closed */
        private boolean closed = false;
    
        public ChunkedInputStream(final InputStream in) {
            super();
            if (in == null) {
                throw new IllegalArgumentException("InputStream parameter may not be null");
            }
            this.in = in;
            this.pos = 0;
        }

        public int read() throws IOException {
            if (this.closed) {
                throw new IOException("Attempted read from closed stream.");
            }
            if (this.eof) {
                return -1;
            } 
            if (this.pos >= this.chunkSize) {
                nextChunk();
                if (this.eof) { 
                    return -1;
                }
            }
            pos++;
            return in.read();
        }

        public int read (byte[] b, int off, int len) throws IOException {

            if (closed) {
                throw new IOException("Attempted read from closed stream.");
            }

            if (eof) { 
                return -1;
            }
            if (pos >= chunkSize) {
                nextChunk();
                if (eof) { 
                    return -1;
                }
            }
            len = Math.min(len, chunkSize - pos);
            int count = in.read(b, off, len);
            pos += count;
            return count;
        }

        public int read (byte[] b) throws IOException {
            return read(b, 0, b.length);
        }

        private void nextChunk() throws IOException {
            chunkSize = getChunkSize();
            if (chunkSize < 0) {
                throw new IOException("Negative chunk size");
            }
            bof = false;
            pos = 0;
            if (chunkSize == 0) {
                eof = true;
            }
        }

        private int getChunkSize() throws IOException {
            // skip CRLF
            if (!bof) {
                int cr = in.read();
                int lf = in.read();
                if ((cr != '\r') || (lf != '\n')) { 
                    throw new IOException(
                                          "CRLF expected at end of chunk");
                }
            }
            //parse data
            String line = readLine();
            if (line == null) {
                throw new IOException(
                                      "Chunked stream ended unexpectedly");
            }
            int separator = line.indexOf(';');
            if (separator < 0) {
                separator = line.length();
            }
            try {
                return Integer.parseInt(line.substring(0, separator).trim(), 16);
            } catch (NumberFormatException e) {
                throw new IOException("Bad chunk header");
            }
        }

        private String readLine() throws IOException {
            char buf[] = lineBuffer;

            if (buf == null) {
                buf = lineBuffer = new char[128];
            }

            int room = buf.length;
            int offset = 0;
            int c;

            loop:	while (true) {
                switch (c = in.read()) {
                case -1:
                case '\n':
                    break loop;

                case '\r':
                    int c2 = in.read();
                    if ((c2 != '\n') && (c2 != -1)) {
                        if (!(in instanceof PushbackInputStream)) {
                            this.in = new PushbackInputStream(in);
                        }
                        ((PushbackInputStream)in).unread(c2);
                    }
                    break loop;

                default:
                    if (--room < 0) {
                        buf = new char[offset + 128];
                        room = buf.length - offset - 1;
                        System.arraycopy(lineBuffer, 0, buf, 0, offset);
                        lineBuffer = buf;
                    }
                    buf[offset++] = (char) c;
                    break;
                }
            }
            if ((c == -1) && (offset == 0)) {
                return null;
            }
            return String.copyValueOf(buf, 0, offset);
        }

        public void close() throws IOException {
            if (!closed) {
                try {
                    if (!eof) {
                        exhaustInputStream(this);
                    }
                } finally {
                    eof = true;
                    closed = true;
                }
            }
        }

        void exhaustInputStream(final InputStream inStream) throws IOException {
            // read and discard the remainder of the message
            byte buffer[] = new byte[1024];
            while (inStream.read(buffer) >= 0) {
                ;
            }
        }
    }

    public class ChunkedOutputStream extends OutputStream {

        private final OutputStream out;

        private byte[] cache;

        private int cachePosition = 0;

        private boolean wroteLastChunk = false;

        private boolean closed = false;

        public ChunkedOutputStream(final OutputStream out, int bufferSize)
            throws IOException {
            super();
            this.cache = new byte[bufferSize];
            this.out = out;
        }

        public ChunkedOutputStream(final OutputStream datatransmitter) 
            throws IOException {
            this(datatransmitter, 2048);
        }

        protected void flushCache() throws IOException {
            if (this.cachePosition > 0) {
                writeBytes(Integer.toHexString(this.cachePosition));
                writeBytes("\r\n");
                this.out.write(this.cache, 0, this.cachePosition);
                writeBytes("\r\n");
                this.cachePosition = 0;
            }
        }

        protected void flushCacheWithAppend(byte bufferToAppend[], int off, int len) throws IOException {
            writeBytes(Integer.toHexString(this.cachePosition + len));
            writeBytes("\r\n");
            this.out.write(this.cache, 0, this.cachePosition);
            this.out.write(bufferToAppend, off, len);
            writeBytes("\r\n");
            this.cachePosition = 0;
        }

        protected void writeClosingChunk() throws IOException {
            // Write the final chunk.
            writeBytes("0\r\n");
            writeBytes("\r\n");
        }

        protected void writeBytes(String s) throws IOException {
            int len = s.length();
            for (int i = 0 ; i < len ; i++) {
                this.out.write((byte)s.charAt(i));
            }
        }
    
        public void finish() throws IOException {
            if (!this.wroteLastChunk) {
                flushCache();
                writeClosingChunk();
                this.wroteLastChunk = true;
            }
        }

        public void write(int b) throws IOException {
            if (this.closed) {
                throw new IOException("Attempted write to closed stream.");
            }
            this.cache[this.cachePosition] = (byte) b;
            this.cachePosition++;
            if (this.cachePosition == this.cache.length) flushCache();
        }

        public void write(byte b[]) throws IOException {
            write(b, 0, b.length);
        }

        public void write(byte src[], int off, int len) throws IOException {
            if (this.closed) {
                throw new IOException("Attempted write to closed stream.");
            }
            if (len >= this.cache.length - this.cachePosition) {
                flushCacheWithAppend(src, off, len);
            } else {
                System.arraycopy(src, off, cache, this.cachePosition, len);
                this.cachePosition += len;
            }
        }

        public void flush() throws IOException {
            flushCache();
            this.out.flush();
        }

        public void close() throws IOException {
            if (!this.closed) {
                this.closed = true;
                finish();
                this.out.flush();
            }
        }
    }
}
