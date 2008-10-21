
import biz.freeside.SelfService;
import org.apache.commons.logging.impl.SimpleLog; // included in apache xmlrpc
import java.util.HashMap;
import java.util.Vector;

public class freeside_signup_example {
  private static SimpleLog logger = new SimpleLog("SelfService");

  public static void main( String args[] ) throws Exception {
    SelfService client =
      new SelfService( "http://192.168.1.221:8081/xmlrpc.cgi" );

    Vector params = new Vector();
    params.addElement( "first" );
    params.addElement( "Test" );
    params.addElement( "last" );
    params.addElement( "User" );
    params.addElement( "address1");
    params.addElement( "123 Test Street" );
    params.addElement( "address2");
    params.addElement( "Suite A" );
    params.addElement( "city");
    params.addElement( "Testville" );
    params.addElement( "state");
    params.addElement( "OH" );
    params.addElement( "zip");
    params.addElement( "44632" );
    params.addElement( "country");
    params.addElement( "US" );
    params.addElement( "daytime" );
    params.addElement( "216-412-1234" );
    params.addElement( "fax" );
    params.addElement( "216-412-1235" );
    params.addElement( "payby" );
    params.addElement( "BILL" );
    params.addElement( "invoicing_list" );
    params.addElement( "test@test.example.com" );
    params.addElement( "pkgpart" );
    params.addElement( "101" );
    params.addElement( "popnum" );
    params.addElement( "4018" );
    params.addElement( "username" );
    params.addElement( "testy" );
    params.addElement( "_password" );
    params.addElement( "tester" );
    HashMap result = client.execute( "new_customer", params );

    String error = (String) result.get("error");

    if (error.length() < 1) {

      // successful signup

      String custnum = (String) result.get("custnum");

      logger.trace("[new_customer] signup with custnum "+custnum);

    }else{

      // unsuccessful signup

      logger.warn("[new_customer] signup error: "+error);

      // display error message to user

    }
  }
}
