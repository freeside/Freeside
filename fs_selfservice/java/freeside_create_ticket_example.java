
import biz.freeside.SelfService;
import org.apache.commons.logging.impl.SimpleLog; //included in apache xmlrpc
import java.util.HashMap;
import java.util.Vector;

public class freeside_create_ticket_example {
  private static SimpleLog logger = new SimpleLog("SelfService");

  public static void main( String args[] ) throws Exception {
    SelfService client =
      new SelfService( "http://192.168.1.221:8081/xmlrpc.cgi" );

    Vector params = new Vector();
    params.addElement( "username" );
    params.addElement( "4155551212" ); // svc_phone.phonenum
    params.addElement( "password" );
    params.addElement( "5454" );       // svc_phone.pin
    params.addElement( "domain" );
    params.addElement( "svc_phone" );
    HashMap result = client.execute( "login", params );

    String error = (String) result.get("error");

    if (error.length() < 1) {

      // successful login

      String sessionId = (String) result.get("session_id");

      logger.trace("[login] logged into freeside with session_id="+sessionId);

      // store session id in your session store to be used for other calls

      // like, say, this one to create a ticket

      Vector ticket_params = new Vector();
      ticket_params.addElement( "session_id" );
      ticket_params.addElement( sessionId );
      ticket_params.addElement( "queue" );
      ticket_params.addElements( 3 ); // otherwise defaults to
                                      // ticket_system-selfservice_queueid
                                      // or ticket_system-default_queueid
      ticket_params.addElement( "requestor" );         // these
      ticket_params.addElement( "email@example.com" ); // are
      ticket_params.addElement( "cc" );                // optional
      ticket_params.addElement( "joe@example.com" );   // 
      ticket_params.addElement( "subject" );
      ticket_params.addElement( "Houston, we have a problem." );
      ticket_params.addElement( "message" );
      ticket_params.addElement( "The Oscillation Overthurster has gone out of alignment!<br><br>It needs to be fixed immediately!  <A HREF=\"http://linktest.freeside.biz/hi\">link test</A>" );
      ticket_params.addElement( "mime_type" );
      ticket_params.addElement( "text/html" );

      HashMap ticket_result = client.execute( "create_ticket", ticket_params);

      String error = (String) ticket_result.get("error");

      if (error.length() < 1) {

        // successful ticket creation

        String ticketId = (String) ticket_result.get("ticket_id");

        logger.trace("[login] ticket created with id="+ticketId);

      } else {

        // unsuccesful creating ticket

        logger.warn("[login] error creating ticket: "+error);

      }

    }else{

      // unsuccessful login

      logger.warn("[login] error logging into freeside: "+error);

      // display/say error message to user

    }
  }
}
