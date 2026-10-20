package agency.optimserve.nativecore;

import android.test.InstrumentationTestCase;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import org.json.JSONObject;

/** Runs on Android without contacting a tracker, media server or account API. */
public final class BackgroundPolicyTest extends InstrumentationTestCase {
    public void testBackgroundBeforeAuthorizationCannotStartPeerEngine() {
        getInstrumentation().runOnMainSync(()->{
            try {
                OptimServeSession session=new OptimServeSession(getInstrumentation().getTargetContext(),"opa_"+repeat('a',32)+"_"+repeat('b',64),"Policy test","com.example.policy");
                session.setBackground(true);
                set(session,"stream","https://media.example/live.m3u8?token=a+b");
                set(session,"mode","p2p");
                set(session,"grant",new JSONObject().put("settings",new JSONObject().put("hide_background_p2p",true)));
                Method start=OptimServeSession.class.getDeclaredMethod("startEngine",int.class);start.setAccessible(true);
                assertEquals("https://media.example/live.m3u8?token=a+b",start.invoke(session,0));
                assertEquals("http",session.snapshot().getString("mode"));
                assertEquals("background_paused",session.snapshot().getString("reason"));
                session.close();
            } catch(Exception error){throw new AssertionError(error);}
        });
    }
    private static String repeat(char value,int count){StringBuilder result=new StringBuilder();for(int i=0;i<count;i++)result.append(value);return result.toString();}
    private static void set(Object target,String name,Object value)throws Exception{Field field=target.getClass().getDeclaredField(name);field.setAccessible(true);field.set(target,value);}
}
