package agency.optimserve.nativecore;

import android.content.Context;
import android.net.ConnectivityManager;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import com.p2pengine.core.p2p.*;
import com.p2pengine.core.tracking.P2pProtocolVersion;
import com.p2pengine.core.utils.EngineException;
import com.p2pengine.sdk.*;
import okhttp3.*;
import org.json.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;

/** Player-independent session. All public methods run on the main thread. */
public final class OptimServeSession implements AutoCloseable {
    public static final String VERSION="0.1.0";
    private static final String BASE="https://p2p.optimserve.agency";
    private static final OkHttpClient HTTP=new OkHttpClient.Builder().connectTimeout(8,TimeUnit.SECONDS).readTimeout(8,TimeUnit.SECONDS).followRedirects(false).followSslRedirects(false).build();
    private static OptimServeSession owner;
    private static P2pEngine engine;
    private static final P2pStatisticsListener NO_STATS=new P2pStatisticsListener(){
        public void onHttpDownloaded(int value){}public void onP2pDownloaded(int value,int speed){}public void onP2pUploaded(int value,int speed){}
        public void onPeers(List<String> peers){}public void onServerConnected(boolean connected){}
    };
    private final Context context;
    private final String key,name,identifier,id;
    private final Handler main=new Handler(Looper.getMainLooper());
    private final ExecutorService network=new ThreadPoolExecutor(1,1,0,TimeUnit.SECONDS,new ArrayBlockingQueue<>(8));
    public interface Listener { void onEvent(JSONObject event); }
    public interface ResultListener { void complete(String json,String error); }
    private Listener listener;
    private JSONObject grant=new JSONObject();
    private String stream="",mode="http",reason="idle",state="paused";
    private volatile int generation;
    private int sequence,peers,settingsVersion,rebuffers,errors;
    private long http,peer,upload,play,buffer,lastTick,checked,expires,renewAt,buffered;
    private volatile boolean closed;
    private boolean started,busy,reporting,background;
    private CompletableFuture<JSONObject> preparing;
    private volatile Call issuance;
    public OptimServeSession(Context context,String appKey,String appName,String appIdentifier){
        this.context=context.getApplicationContext();key=appKey;name=appName;identifier=appIdentifier;
        if(key==null||!key.matches("opa_[a-fA-F0-9]{32}_[a-fA-F0-9]{64}")||name==null||name.trim().isEmpty()||name.length()>80||identifier==null||!identifier.matches("[A-Za-z0-9._-]{1,160}"))throw new IllegalArgumentException("Copy your App Key and App ID from OptimServe.");
        String raw=key.substring(4,36);id=raw.substring(0,8)+"-"+raw.substring(8,12)+"-"+raw.substring(12,16)+"-"+raw.substring(16,20)+"-"+raw.substring(20);
    }
    private static void mainThread(){if(Looper.myLooper()!=Looper.getMainLooper())throw new IllegalStateException("Use the main thread for OptimServe controls.");}
    public void setListener(Listener value){mainThread();listener=value;}
    private void emit(String type,JSONObject data){if(listener!=null)try{listener.onEvent(new JSONObject().put("type",type).put(type.equals("stats")?"stats":"playback",data));}catch(JSONException ignored){}}
    private static HttpUrl endpoint(String address){
        HttpUrl url=HttpUrl.parse(address);
        if(url==null||!url.isHttps()||!url.host().equals("p2p.optimserve.agency")||url.port()!=443||!url.username().isEmpty()||!url.password().isEmpty()||url.fragment()!=null||url.query()!=null||!url.encodedPath().matches("/api/native/(apps/[a-fA-F0-9-]{36}/sessions|sessions/[a-fA-F0-9]{64}/(renew|reports|configuration|stop))"))throw new IllegalArgumentException("Invalid OptimServe endpoint.");
        return url;
    }
    private static Call call(String address,JSONObject body){return HTTP.newCall(new Request.Builder().url(endpoint(address)).post(RequestBody.create(MediaType.parse("application/json"),body.toString())).build());}
    private static JSONObject response(Call call)throws Exception{
        try(Response response=call.execute()){
            if(!response.isSuccessful()||response.body()==null)throw new IOException("Delivery unavailable");
            ByteArrayOutputStream bytes=new ByteArrayOutputStream();try(InputStream input=response.body().byteStream()){
                byte[] block=new byte[4096];int count;while((count=input.read(block))!=-1){if(bytes.size()+count>131072)throw new IOException("Invalid delivery response");bytes.write(block,0,count);}}
            return new JSONObject(new String(bytes.toByteArray(),StandardCharsets.UTF_8));
        }
    }
    private static JSONObject post(String address,JSONObject body)throws Exception{return response(call(address,body));}
    public CompletableFuture<JSONObject> prepare(String url,String streamId){
        mainThread();if(closed)throw new IllegalStateException("Session is closed.");
        HttpUrl media=HttpUrl.parse(url);
        if(media==null||!media.isHttps()||!media.username().isEmpty()||!media.password().isEmpty()||media.fragment()!=null||url.length()>2048||streamId!=null&&!streamId.matches("[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}"))throw new IllegalArgumentException("Use an HTTPS media URL and valid optional Stream ID.");
        if(owner!=null&&owner!=this)throw new IllegalStateException("Stop the other OptimServe session first.");
        if(((ThreadPoolExecutor)network).getQueue().remainingCapacity()<2)throw new IllegalStateException("Playback setup is busy. Try again shortly.");
        stop();owner=this;stream=url;mode="http";reason="authorizing";state="paused";sequence=0;http=peer=upload=play=buffer=0;peers=errors=rebuffers=0;started=busy=reporting=false;lastTick=SystemClock.elapsedRealtime();
        final int run=generation;final CompletableFuture<JSONObject> pending=new CompletableFuture<>();preparing=pending;
        final JSONObject input=new JSONObject();
        try{ConnectivityManager connection=(ConnectivityManager)context.getSystemService(Context.CONNECTIVITY_SERVICE);input.put("key",key).put("app_name",name).put("app_identifier",identifier).put("platform","android").put("stream",url).put("stream_id",streamId).put("selection",ThreadLocalRandom.current().nextInt(100)).put("metered",connection==null||connection.isActiveNetworkMetered());}catch(JSONException impossible){throw new IllegalStateException(impossible);}
        network.execute(()->{
            if(closed||run!=generation){pending.completeExceptionally(new CancellationException("Playback setup cancelled."));return;}
            JSONObject result;Call current=call(BASE+"/api/native/apps/"+id+"/sessions",input);issuance=current;
            try{result=response(current);}catch(Exception error){result=null;}finally{if(issuance==current)issuance=null;}
            final JSONObject received=result;
            main.post(()->{
                if(closed||run!=generation){if(received!=null)release(received);pending.completeExceptionally(new CancellationException("Playback setup cancelled."));return;}
                preparing=null;
                if(received==null||!valid(received)){reason="authorization_unavailable";pending.complete(playback(url));return;}
                grant=received;settingsVersion=grant.optJSONObject("settings").optInt("version");expires=SystemClock.elapsedRealtime()+590000;renewAt=SystemClock.elapsedRealtime()+480000;checked=SystemClock.elapsedRealtime();
                mode=grant.optString("mode","http");reason=grant.optString("reason","http");String parsed=url;
                if(mode.equals("p2p"))try{if(!grant.isNull("ad")||grant.getJSONObject("settings").optJSONArray("segment_bypass_paths").length()>0)throw new IllegalStateException("Player policy unavailable");parsed=startEngine(run);}catch(Exception|LinkageError error){fallback("peer_engine_unavailable");parsed=url;}
                main.postDelayed(tick,1000);pending.complete(playback(parsed));
            });
        });return pending;
    }
    private boolean valid(JSONObject data){try{
        if(!Arrays.asList("http","p2p").contains(data.getString("mode"))||data.getInt("expiresIn")!=600||data.getJSONObject("settings").getInt("version")<1)return false;
        for(String field:new String[]{"renew","report","stop","configuration"})endpoint(data.getString(field));
        if(data.getString("mode").equals("p2p")){
            HttpUrl announce=HttpUrl.parse(data.getString("announce"));String signal=data.getJSONObject("signalConfig").getString("main");
            if(announce==null||!announce.isHttps()||!announce.host().equals("p2p.optimserve.agency")||!announce.encodedPath().matches("/api/native/sessions/[a-f0-9]{64}/v1")||!signal.matches("wss://p2p\\.optimserve\\.agency/api/native/signal/[a-f0-9]{64}"))return false;
            data.getString("channelId");data.getString("token");
        }return true;
    }catch(Exception error){return false;}}
    public void prepareJSON(String url,String streamId,ResultListener callback){prepare(url,streamId).whenComplete((value,error)->callback.complete(value==null?null:value.toString(),error==null?null:"Playback setup cancelled."));}
    private String startEngine(final int run)throws Exception{
        if(background&&grant.getJSONObject("settings").optBoolean("hide_background_p2p")){fallback("background_paused");return stream;}
        JSONObject settings=grant.getJSONObject("settings");ArrayList<g> ice=new ArrayList<>();ice.add(new g("stun:stun.l.google.com:19302"));ice.add(new g("stun:global.stun.twilio.com:3478"));
        P2pConfig config=new P2pConfig.Builder().announce(grant.getString("announce")).signalConfig(grant.getJSONObject("signalConfig").getString("main"),null).p2pProtocolVersion(P2pProtocolVersion.V8).iceServers(ice).geoIpPreflight(false).ICEPreflight(false).useHttpRange(settings.getBoolean("use_http_range")).prefetchOnly(settings.getBoolean("prefetch_only")).diskCacheLimit(0).memoryCacheCountLimit(10).logEnabled(false).build();
        if(engine==null)engine=P2pEngine.init(context,grant.getString("token"),config);else{engine.setP2pConfig(config);M3u8Proxy.Companion.getInstance().startLocalServer();}
        engine.registerExceptionListener(new EngineExceptionListener(){public void onTrackerException(EngineException e){fail();}public void onSignalException(EngineException e){fail();}public void onSchedulerException(EngineException e){fail();}public void onOtherException(EngineException e){fail();}private void fail(){main.post(()->{if(run==generation)fallback("peer_engine_unavailable");});}});
        engine.addP2pStatisticsListener(new P2pStatisticsListener(){
            public void onHttpDownloaded(int value){main.post(()->{if(run==generation&&mode.equals("p2p")&&value>0)http+=value;});}
            public void onP2pDownloaded(int value,int speed){main.post(()->{if(run==generation&&mode.equals("p2p")&&value>0)peer+=value;});}
            public void onP2pUploaded(int value,int speed){main.post(()->{if(run==generation&&mode.equals("p2p")&&value>0)upload+=value;});}
            public void onPeers(List<String> values){int count=values.size();main.post(()->{if(run==generation&&mode.equals("p2p"))peers=count;});}
            public void onServerConnected(boolean connected){}
        });engine.setPlayerInteractor(new PlayerInteractor(){public long onBufferedDuration(){return buffered;}});
        return engine.parseStreamUrl(stream,grant.getString("channelId"));
    }
    private void countTime(){long now=SystemClock.elapsedRealtime(),delta=Math.max(0,Math.min(2000,now-lastTick));lastTick=now;if(state.equals("playing")){play+=delta;started=true;}if(state.equals("buffering"))buffer+=delta;}
    public void updatePlayback(String value,double bufferedMs,double positionMs){mainThread();if(!Arrays.asList("playing","paused","buffering","stopped").contains(value))throw new IllegalArgumentException("Invalid playback state.");countTime();if(value.equals("buffering")&&!state.equals(value)&&started)rebuffers=Math.min(100000,rebuffers+1);state=value;buffered=Double.isFinite(bufferedMs)?(long)Math.max(0,bufferedMs):0;}
    public void setBackground(boolean background){mainThread();this.background=background;if(background&&grant.optJSONObject("settings")!=null&&grant.optJSONObject("settings").optBoolean("hide_background_p2p"))fallback("background_paused");}
    public JSONObject snapshot(){mainThread();try{return new JSONObject().put("http_kib",mode.equals("p2p")||http>0?http:JSONObject.NULL).put("peer_kib",peer).put("upload_kib",upload).put("play_ms",play).put("buffer_ms",buffer).put("peers",peers).put("mode",mode).put("reason",reason).put("reporting",reporting);}catch(JSONException impossible){throw new IllegalStateException(impossible);}}
    private JSONObject playback(String url){try{return new JSONObject().put("url",url).put("mode",mode).put("reason",reason);}catch(JSONException impossible){throw new IllegalStateException(impossible);}}
    private JSONObject report(boolean stopped){try{return new JSONObject().put("sequence",++sequence).put("http_kib",http).put("peer_kib",peer).put("upload_kib",upload).put("play_ms",play).put("buffer_ms",buffer).put("rebuffers",rebuffers).put("errors",errors).put("started",started).put("state",stopped?"stopped":state).put("runtime",new JSONObject().put("sdk","3.14.0").put("adapter","native").put("adapter_version",VERSION).put("player","player"));}catch(JSONException impossible){throw new IllegalStateException(impossible);}}
    private final Runnable tick=new Runnable(){public void run(){
        if(closed||owner!=OptimServeSession.this)return;countTime();emit("stats",snapshot());long now=SystemClock.elapsedRealtime();if(now>=expires)fallback("session_expired");
        if(!busy&&now-checked>=10000){busy=true;checked=now;final int run=generation;final JSONObject captured=grant,payload=report(false);final boolean renewing=now>=renewAt;final boolean p2p=mode.equals("p2p");
            network.execute(()->{JSONObject result=null;try{post(captured.getString("report"),payload);JSONObject body=new JSONObject();if(!p2p)body.put("p2p",false);result=post(captured.getString(renewing?"renew":"configuration"),body);}catch(Exception ignored){}final JSONObject next=result;
                main.post(()->{if(run!=generation||closed)return;busy=false;reporting=next!=null;if(next==null){fallback("access_check_unavailable");return;}
                    if(renewing){if(next.optInt("expiresIn")!=600||!next.optString("session_id").equals(captured.optString("session_id"))){fallback("renewal_invalid");return;}expires=SystemClock.elapsedRealtime()+590000;renewAt=SystemClock.elapsedRealtime()+480000;}
                    if(!next.optString("mode").equals("p2p")||next.optJSONObject("settings")==null||next.optJSONObject("settings").optInt("version")!=settingsVersion)fallback("delivery_settings_changed");
                });});}
        main.postDelayed(this,1000);
    }};
    private static void stopPeerEngine(){
        if(engine!=null){engine.disableP2p();engine.stopP2p();engine.removePlayerInteractor();engine.unregisterExceptionListener();engine.addP2pStatisticsListener(NO_STATS);engine.setHttpHeadersForHls(Collections.emptyMap());
            // Retain the process executor; upstream destroy() prevents a working later init().
            M3u8Proxy.Companion.getInstance().shutdown();MpdProxy.Companion.getInstance().shutdown();}
    }
    private void fallback(String why){if(!mode.equals("p2p"))return;mode="http";reason=why;peers=0;stopPeerEngine();emit("url",playback(stream));}
    private void release(JSONObject previous){try{if(previous.has("stop"))call(previous.getString("stop"),new JSONObject()).enqueue(new Callback(){public void onFailure(Call call,IOException error){}public void onResponse(Call call,Response response){response.close();}});}catch(Exception ignored){}}
    public void stop(){
        mainThread();if(closed)return;countTime();generation++;main.removeCallbacks(tick);Call pending=issuance;if(pending!=null)pending.cancel();if(preparing!=null){preparing.completeExceptionally(new CancellationException("Playback setup cancelled."));preparing=null;}
        if(owner==this){stopPeerEngine();owner=null;}
        final JSONObject previous=grant,payload=report(true);grant=new JSONObject();mode="http";state="stopped";
        if(previous.has("report"))try{network.execute(()->{try{post(previous.optString("report"),payload);}catch(Exception ignored){}finally{release(previous);}});}catch(RejectedExecutionException full){release(previous);}
    }
    @Override public void close(){mainThread();if(closed)return;stop();closed=true;listener=null;network.shutdown();}
}
