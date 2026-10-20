package agency.optimserve.uniapp;
import agency.optimserve.nativecore.OptimServeSession;
import io.dcloud.feature.uniapp.common.UniModule;
import io.dcloud.feature.uniapp.annotation.UniJSMethod;
import io.dcloud.feature.uniapp.bridge.UniJSCallback;
import com.alibaba.fastjson.JSONObject;
import com.alibaba.fastjson.JSONArray;
public final class OptimServeModule extends UniModule {
    private OptimServeSession session;
    private UniJSCallback events;
    private void reply(UniJSCallback callback,Object value,String error){if(callback==null)return;JSONObject out=new JSONObject();if(error==null)out.put("value",value);else out.put("error",error);callback.invoke(out);}
    @UniJSMethod(uiThread=true) public void subscribe(JSONObject options,UniJSCallback callback){events=callback;}
    @UniJSMethod(uiThread=true) public void unsubscribe(JSONObject options){events=null;}
    @UniJSMethod(uiThread=true) public void call(JSONObject options,UniJSCallback callback){try{
        JSONArray args=options.getJSONArray("args");String method=options.getString("method");
        if("configure".equals(method)){if(session!=null)session.close();session=new OptimServeSession(mUniSDKInstance.getContext(),args.getString(0),args.getString(1),args.getString(2));session.setListener(event->{if(events!=null)events.invokeAndKeepAlive(event.toString());});reply(callback,null,null);return;}
        if("close".equals(method)){if(session!=null)session.close();session=null;events=null;reply(callback,null,null);return;}
        if(session==null)throw new IllegalStateException("Create the OptimServe session first.");
        switch(method){
            case "prepare":session.prepare(args.getString(0),args.getString(1)).whenComplete((value,error)->reply(callback,error==null?value.toString():null,error==null?null:"Playback setup cancelled."));return;
            case "updatePlayback":session.updatePlayback(args.getString(0),args.getDoubleValue(1),args.getDoubleValue(2));break;
            case "setBackground":session.setBackground(args.getBooleanValue(0));break;
            case "snapshot":reply(callback,session.snapshot().toString(),null);return;
            case "stop":session.stop();break;
            default:throw new IllegalArgumentException("Unknown OptimServe method.");
        }reply(callback,null,null);
    }catch(Exception error){reply(callback,null,error.getMessage());}}
    @Override public void onActivityDestroy(){if(session!=null)session.close();session=null;events=null;super.onActivityDestroy();}
}
