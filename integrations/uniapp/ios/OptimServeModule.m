#import "OptimServeModule.h"
#import <OptimServe/OptimServe-Swift.h>
@interface OptimServeModule ()
@property(nonatomic,strong) OSSession *session;
@property(nonatomic,copy) UniModuleKeepAliveCallback events;
@end
@implementation OptimServeModule
UNI_EXPORT_METHOD(@selector(call:callback:))
UNI_EXPORT_METHOD(@selector(subscribe:callback:))
UNI_EXPORT_METHOD(@selector(unsubscribe:))
- (void)subscribe:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback { self.events=callback; }
- (void)unsubscribe:(NSDictionary *)options { if(self.events)self.events(@{},NO);self.events=nil; }
- (void)call:(NSDictionary *)options callback:(UniModuleKeepAliveCallback)callback {
    NSString *method=options[@"method"];NSArray *args=options[@"args"] ?: @[];
    void (^reply)(id,NSString *)=^(id value,NSString *error){if(callback)callback(error?@{@"error":error}:@{@"value":value ?: NSNull.null},NO);};
    if([method isEqual:@"configure"]){
        if(args.count!=3){reply(nil,@"Provide your app information.");return;}
        [self.session close];NSError *error=nil;
        self.session=[[OSSession alloc] initWithAppKey:args[0] appName:args[1] appIdentifier:args[2] error:&error];
        if(error){reply(nil,@"Check your App Key and App ID.");return;}
        __weak OptimServeModule *weakSelf=self;
        self.session.onEvent=^(NSDictionary *event){if(weakSelf.events)weakSelf.events(event,YES);};reply(nil,nil);return;
    }
    if([method isEqual:@"close"]){[self.session close];self.session=nil;[self unsubscribe:@{}];reply(nil,nil);return;}
    if(!self.session){reply(nil,@"Create the OptimServe session first.");return;}
    if([method isEqual:@"prepare"]&&args.count==2){[self.session prepare:args[0] streamID:args[1]==NSNull.null?nil:args[1] completion:^(NSDictionary *value,NSError *error){reply(value,error.localizedDescription);}];return;}
    if([method isEqual:@"updatePlayback"]&&args.count==3){[self.session updatePlayback:args[0] bufferedMs:[args[1] doubleValue] positionMs:[args[2] doubleValue]];reply(nil,nil);return;}
    if([method isEqual:@"setBackground"]&&args.count==1){[self.session setBackground:[args[0] boolValue]];reply(nil,nil);return;}
    if([method isEqual:@"snapshot"]){reply([self.session snapshot],nil);return;}
    if([method isEqual:@"stop"]){[self.session stop];reply(nil,nil);return;}
    reply(nil,@"Unknown OptimServe method.");
}
- (void)dealloc { OSSession *core=self.session;dispatch_async(dispatch_get_main_queue(),^{[core close];}); }
@end
