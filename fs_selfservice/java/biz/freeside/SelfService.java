package biz.freeside;

// see http://ws.apache.org/xmlrpc/client.html for these classes
import org.apache.xmlrpc.XmlRpcException;
import org.apache.xmlrpc.client.XmlRpcClient;
import org.apache.xmlrpc.client.XmlRpcClientConfig;
import org.apache.xmlrpc.client.XmlRpcClientConfigImpl;

import java.util.HashMap;
import java.util.List;
import java.net.URL;

public class SelfService extends XmlRpcClient {

  public SelfService( String url ) throws Exception {
    super();
    XmlRpcClientConfigImpl config = new XmlRpcClientConfigImpl();
    config.setServerURL(new URL( url ));
    this.setConfig(config);
  }

  private String canonicalMethod ( String method ) {
    String canonical = new String(method);
    if (!canonical.startsWith( "FS.SelfService.XMLRPC." )) {
      canonical = "FS.SelfService.XMLRPC." + canonical;
    }
    return canonical;
  }

  private HashMap testResponse ( Object toTest ) throws XmlRpcException {
    if (! ( toTest instanceof HashMap )) {
      throw new XmlRpcException("expected HashMap but got" + toTest.getClass());
    }
    return (HashMap) toTest;
  }

  public HashMap execute( String method, List params ) throws XmlRpcException {
    return testResponse(super.execute( canonicalMethod(method), params ));
  }

  public HashMap execute( String method, Object[] params ) throws XmlRpcException {
    return testResponse(super.execute( canonicalMethod(method), params ));
  }

  public HashMap execute( XmlRpcClientConfig config, String method, List params ) throws XmlRpcException {
    return testResponse(super.execute( config, canonicalMethod(method), params ));
  }

  public HashMap execute( XmlRpcClientConfig config, String method, Object[] params ) throws XmlRpcException {
    return testResponse(super.execute( config, canonicalMethod(method), params ));
  }
}
