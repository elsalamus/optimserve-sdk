package agency.optimserve.flutter;
import agency.optimserve.nativecore.OptimServeSession;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.*;
import android.content.Context;
public final class OptimServePlugin implements FlutterPlugin,MethodChannel.MethodCallHandler,EventChannel.StreamHandler {
    private OptimServeSession session;
    private Context context;
    private MethodChannel methods;
    private EventChannel events;
    private EventChannel.EventSink sink;
    @Override public void onAttachedToEngine(FlutterPluginBinding binding){context=binding.getApplicationContext();methods=new MethodChannel(binding.getBinaryMessenger(),"optimserve/methods");methods.setMethodCallHandler(this);events=new EventChannel(binding.getBinaryMessenger(),"optimserve/events");events.setStreamHandler(this);}
    @Override public void onDetachedFromEngine(FlutterPluginBinding binding){if(session!=null)session.close();session=null;sink=null;methods.setMethodCallHandler(null);events.setStreamHandler(null);}
    @Override public void onListen(Object args,EventChannel.EventSink value){sink=value;}
    @Override public void onCancel(Object args){sink=null;}
    private double number(MethodCall call,String name){Number value=call.argument(name);return value==null?0:value.doubleValue();}
    @Override public void onMethodCall(MethodCall call,MethodChannel.Result result){try{
        if(call.method.equals("configure")){if(session!=null)session.close();session=new OptimServeSession(context,call.argument("key"),call.argument("name"),call.argument("id"));session.setListener(event->{if(sink!=null)sink.success(event.toString());});result.success(null);return;}
        if(call.method.equals("close")){if(session!=null)session.close();session=null;result.success(null);return;}
        if(session==null)throw new IllegalStateException("Create the OptimServe session first.");
        switch(call.method){
            case "prepare":session.prepare(call.argument("url"),call.argument("streamId")).whenComplete((value,error)->{if(error==null)result.success(value.toString());else result.error("OPTIMSERVE","Playback setup cancelled.",null);});return;
            case "updatePlayback":session.updatePlayback(call.argument("state"),number(call,"buffered"),number(call,"position"));break;
            case "setBackground":session.setBackground(Boolean.TRUE.equals(call.argument("value")));break;
            case "snapshot":result.success(session.snapshot().toString());return;
            case "stop":session.stop();break;
            default:result.notImplemented();return;
        }result.success(null);
    }catch(Exception error){result.error("OPTIMSERVE",error.getMessage(),null);}}
}
