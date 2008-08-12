import sun.misc.BASE64Encoder;
import java.security.cert.Certificate;
import java.security.*;
import java.io.File;
import java.io.FileInputStream;

class ExportPriv {
    public static void main(String args[]) throws Exception{
		if (args.length < 2) {
			//Yes I know this sucks (the password is visible to other users via ps
			// but this was a quick-n-dirty fix to export from a keystore to pkcs12
			// someday I may fix, but for now it'll have to do.
			System.err.println("Usage: java ExportPriv <keystore> <alias> <password>");
			System.exit(1);
		}
		ExportPriv myep = new ExportPriv();
		myep.doit(args[0], args[1], args[2]);
    }

    public void doit(String fileName, String aliasName, String pass) throws Exception{

	KeyStore ks = KeyStore.getInstance("JKS");

	char[] passPhrase = pass.toCharArray();
	BASE64Encoder myB64 = new BASE64Encoder();

	File certificateFile = new File(fileName);
	ks.load(new FileInputStream(certificateFile), passPhrase);

	KeyPair kp = getPrivateKey(ks, aliasName, passPhrase);
		
	PrivateKey privKey = kp.getPrivate();

	String b64 = myB64.encode(privKey.getEncoded());

	System.out.println("-----BEGIN PRIVATE KEY-----");
	System.out.println(b64);
	System.out.println("-----END PRIVATE KEY-----");

	}

// From http://javaalmanac.com/egs/java.security/GetKeyFromKs.html

   public KeyPair getPrivateKey(KeyStore keystore, String alias, char[] password) {
        try {
            // Get private key
            Key key = keystore.getKey(alias, password);
            if (key instanceof PrivateKey) {
                // Get certificate of public key
                Certificate cert = keystore.getCertificate(alias);
    
                // Get public key
                PublicKey publicKey = cert.getPublicKey();
    
                // Return a key pair
                return new KeyPair(publicKey, (PrivateKey)key);
            }
        } catch (UnrecoverableKeyException e) {
        } catch (NoSuchAlgorithmException e) {
        } catch (KeyStoreException e) {
        }
        return null;
    }

}

