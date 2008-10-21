
import biz.freeside.SelfService;
import org.apache.commons.logging.impl.SimpleLog; //included in apache xmlrpc
import java.util.HashMap;
import java.util.Vector;

public class freeside_login_example {
  private static SimpleLog logger = new SimpleLog("SelfService");

  public static void main( String args[] ) throws Exception {
    SelfService client =
      new SelfService( "http://192.168.1.221:8081/xmlrpc.cgi" );

    Vector params = new Vector();
    params.addElement( "username" );
    params.addElement( "testuser" );
    params.addElement( "domain" );
    params.addElement( "example.com" );
    params.addElement( "password" );
    params.addElement( "testpass" );
    HashMap result = client.execute( "login", params );

    String error = (String) result.get("error");

    if (error.length() < 1) {

      // successful login

      String sessionId = (String) result.get("session_id");

      logger.trace("[login] logged into freeside with session_id="+sessionId);

      // store session id in your session store to be used for other calls

    }else{

      // successful login

      logger.warn("[login] error logging into freeside: "+error);

      // display error message to user

    }
  }
}
