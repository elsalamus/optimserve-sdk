package agency.optimserve.reactnative;
import agency.optimserve.nativecore.OptimServeSession;
import com.facebook.react.bridge.*;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import org.json.JSONObject;
public final class OptimServeModule extends ReactContextBaseJavaModule {
    private OptimServeSession session;
    public OptimServeModule(ReactApplicationContext context){super(context);}
    @Override public String getName(){return "OptimServe";}
    private void action(Promise promise,Runnable work){UiThreadUtil.runOnUiThread(()->{try{work.run();}catch(Exception error){promise.reject("OPTIMSERVE",error.getMessage());}});}
    private OptimServeSession current(){if(session==null)throw new IllegalStateException("Create the OptimServe session first.");return session;}
    @ReactMethod public void configure(String key,String name,String id,Promise promise){action(promise,()->{if(session!=null)session.close();session=new OptimServeSession(getReactApplicationContext(),key,name,id);session.setListener(event->getReactApplicationContext().getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class).emit("OptimServeEvent",event.toString()));promise.resolve(null);});}
    @ReactMethod public void prepare(String url,String id,Promise promise){action(promise,()->current().prepare(url,id).whenComplete((result,error)->{if(error!=null)promise.reject("OPTIMSERVE","Playback setup cancelled.");else promise.resolve(result.toString());}));}
    @ReactMethod public void updatePlayback(String state,double buffered,double position,Promise promise){action(promise,()->{current().updatePlayback(state,buffered,position);promise.resolve(null);});}
    @ReactMethod public void setBackground(boolean value,Promise promise){action(promise,()->{current().setBackground(value);promise.resolve(null);});}
    @ReactMethod public void snapshot(Promise promise){action(promise,()->promise.resolve(current().snapshot().toString()));}
    @ReactMethod public void stop(Promise promise){action(promise,()->{current().stop();promise.resolve(null);});}
    @ReactMethod public void close(Promise promise){action(promise,()->{if(session!=null)session.close();session=null;promise.resolve(null);});}
    @ReactMethod public void addListener(String event){}
    @ReactMethod public void removeListeners(double count){}
    @Override public void invalidate(){UiThreadUtil.runOnUiThread(()->{if(session!=null)session.close();session=null;});super.invalidate();}
}
