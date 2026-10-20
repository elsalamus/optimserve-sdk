package agency.optimserve.reactnative;
import com.facebook.react.ReactPackage;
import com.facebook.react.bridge.*;
import com.facebook.react.uimanager.ViewManager;
import java.util.*;
public final class OptimServePackage implements ReactPackage {
    public List<NativeModule> createNativeModules(ReactApplicationContext context){return Collections.singletonList(new OptimServeModule(context));}
    public List<ViewManager> createViewManagers(ReactApplicationContext context){return Collections.emptyList();}
}
