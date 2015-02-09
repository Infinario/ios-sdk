//
//  Infinario.m
//  InfinarioSDK
//
//  Created by Igi on 2/4/15.
//  Copyright (c) 2015 Infinario. All rights reserved.
//

#import "Infinario.h"
#import "Preferences.h"
#import "Customer.h"
#import "Event.h"
#import "CommandManager.h"

int const FLUSH_COUNT = 50;
double const FLUSH_DELAY = 10.0;

@interface Infinario ()

@property NSString *token;
@property NSString *target;
@property NSDictionary *customer;
@property CommandManager *commandManager;
@property Preferences *preferences;
@property BOOL identified;
@property int commandCounter;
@property (nonatomic) BOOL automaticFlushing;
@property NSTimer *flushTimer;
@property UIBackgroundTaskIdentifier task;

@end

@implementation Infinario

- (instancetype)initWithToken:(NSString *)token andWithTarget:(NSString *)target andWithCustomer:(NSMutableDictionary *)customer {
    self = [super init];
    
    self.token = token;
    self.target = target ? target : @"https://api.infinario.com";
    
    self.commandManager = [[CommandManager alloc] initWithTarget:self.target];
    self.preferences = [[Preferences alloc] init];
    
    self.identified = NO;
    self.customer = nil;
    self.commandCounter = FLUSH_COUNT;
    self.task = UIBackgroundTaskInvalid;
    
    id autoFlushing = [self.preferences objectForKey:@"automatic_flushing"];
    
    if (autoFlushing != nil) {
        _automaticFlushing = [autoFlushing boolValue];
    }
    else {
        self.automaticFlushing = YES;
    }
    
    if (customer) [self identifyWithCustomerDict:customer];
    
    return self;
}

+ (id)sharedInstanceWithToken:(NSString *)token andWithTarget:(NSString *)target andWithCustomerDict:(NSMutableDictionary *)customer {
    static dispatch_once_t p = 0;
    
    __strong static id _sharedObject = nil;
    
    dispatch_once(&p, ^{
        _sharedObject = [[self alloc] initWithToken:token andWithTarget:target andWithCustomer:customer];
    });
    
    return _sharedObject;
}

+ (id)sharedInstanceWithToken:(NSString *)token andWithTarget:(NSString *)target andWithCustomer:(NSString *)customer {
    return [self sharedInstanceWithToken:token andWithTarget:target andWithCustomerDict:[self customerDict:customer]];
}

+ (id)sharedInstanceWithToken:(NSString *)token andWithTarget:(NSString *)target {
    return [self sharedInstanceWithToken:token andWithTarget:target andWithCustomerDict:nil];
}

+ (id)sharedInstanceWithToken:(NSString *)token andWithCustomerDict:(NSMutableDictionary *)customer {
    return [self sharedInstanceWithToken:token andWithTarget:nil andWithCustomerDict:customer];
}

+ (id)sharedInstanceWithToken:(NSString *)token andWithCustomer:(NSString *)customer {
    return [self sharedInstanceWithToken:token andWithTarget:nil andWithCustomerDict:[self customerDict:customer]];
}

+ (id)sharedInstanceWithToken:(NSString *)token {
    return [self sharedInstanceWithToken:token andWithTarget:nil andWithCustomerDict:nil];
}

+ (NSMutableDictionary *)customerDict:(NSString *)customer {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    
    if (customer) {
        dict[@"registered"] = customer;
    }
    
    return dict;
}

- (void)identifyWithCustomerDict:(NSMutableDictionary *)customer andUpdate:(NSDictionary *)properties {
    if (!(customer[@"cookie"] && [customer[@"cookie"] length])) {
        customer[@"cookie"] = [self getCookie];
    }
    
    self.customer = customer;
    self.identified = YES;
    
    if (properties) [self update:properties];
}

- (void)identifyWithCustomer:(NSString *)customer andUpdate:(NSDictionary *)properties {
    [self identifyWithCustomerDict:[[self class] customerDict:customer] andUpdate:properties];
}

- (void)identifyWithCustomerDict:(NSMutableDictionary *)customer {
    [self identifyWithCustomerDict:customer andUpdate:nil];
}

- (void)identifyWithCustomer:(NSString *)customer {
    [self identifyWithCustomer:customer andUpdate:nil];
}

- (void)unidentify {
    [self.preferences removeObjectForKey:@"cookie"];
    self.identified = NO;
    self.customer = nil;
}

- (void)update:(NSDictionary *)properties {
    if (!self.identified) [self identifyWithCustomer:nil];
    
    Customer *customer = [[Customer alloc] initWithIds:self.customer andProjectId:self.token andWithProperties:properties];
    
    [self.commandManager schedule:customer];
    
    if (self.automaticFlushing) [self setupDelayedFlush];
}

- (void)track:(NSString *)type withProperties:(NSDictionary *)properties withTimestamp:(NSNumber *)timestamp {
    if (!self.identified) [self identifyWithCustomer:nil];
    
    Event *event = [[Event alloc] initWithIds:self.customer andProjectId:self.token andWithType:type andWithProperties:properties andWithTimestamp:timestamp];
    
    [self.commandManager schedule:event];
    
    if (self.automaticFlushing) [self setupDelayedFlush];
}

- (void)track:(NSString *)type withProperties:(NSDictionary *)properties {
    [self track:type withProperties:properties withTimestamp:nil];
}

- (void)track:(NSString *)type withTimestamp:(NSNumber *)timestamp {
    [self track:type withProperties:nil withTimestamp:timestamp];
}

- (void)track:(NSString *)type {
    [self track:type withProperties:nil withTimestamp:nil];
}

- (void)flush {
    [self ensureBackgroundTask];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.commandManager flush];
        [self ensureBackgroundTaskFinished];
    });
}

- (void)ensureBackgroundTask {
    UIApplication *app = [UIApplication sharedApplication];
    
    if (self.task == UIBackgroundTaskInvalid) {
        self.task = [app beginBackgroundTaskWithExpirationHandler:^{
            [app endBackgroundTask:self.task];
            self.task = UIBackgroundTaskInvalid;
        }];
    }
}

- (void)ensureBackgroundTaskFinished {
    if (self.task != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.task];
        self.task = UIBackgroundTaskInvalid;
    }
}

- (NSString *)getCookie {
    NSString *cookie = [self.preferences objectForKey:@"cookie"];
    
    if (!cookie) {
        CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
        cookie = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
        CFRelease(uuid);
        
        [self.preferences setObject:cookie forKey:@"cookie"];
    }
    
    return cookie;
}

- (void)setupDelayedFlush {
    if (self.commandCounter > 0) {
        self.commandCounter--;
        [self startFlushTimer];
    }
    else {
        self.commandCounter = FLUSH_COUNT;
        [self stopFlushTimer];
        [self flush];
    }
}

- (void)setAutomaticFlushing:(BOOL)automaticFlushing {
    [self.preferences setObject:[NSNumber numberWithBool:automaticFlushing] forKey:@"automatic_flushing"];
    _automaticFlushing = automaticFlushing;
}

- (void)enableAutomaticFlushing {
    self.automaticFlushing = YES;
}

- (void)disableAutomaticFlushing {
    self.automaticFlushing = NO;
}

- (void)startFlushTimer {
    [self stopFlushTimer];
    [self ensureBackgroundTask];
    
    self.flushTimer = [NSTimer scheduledTimerWithTimeInterval:FLUSH_DELAY target:self selector:@selector(onFlushTimer:) userInfo:nil repeats:NO];
}

- (void)stopFlushTimer {
    if (self.flushTimer) {
        [self.flushTimer invalidate];
        self.flushTimer = nil;
    }
}

- (void)onFlushTimer:(NSTimer *)timer {
    if (self.automaticFlushing) [self flush];
    
    [self ensureBackgroundTaskFinished];
}

- (void)registerPushNotifications {
    UIUserNotificationType types = UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound;
    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
    [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    [[UIApplication sharedApplication] registerForRemoteNotifications];
}

- (void)addPushNotificationsToken:(NSData *)token {
    [self update:@{@"__ios_device_token": [[NSString alloc] initWithData:token encoding:NSUTF8StringEncoding]}];
}

@end
