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
#import "Http.h"
#import "Session.h"
#import "Device.h"
#import "InfinarioSegment.h"
#import <AdSupport/ASIdentifierManager.h>

int const FLUSH_COUNT = 50;
double const FLUSH_DELAY = 10.0;
double const SESSION_TIMEOUT = 60.0;

@interface Infinario ()

@property NSString *token;
@property NSString *target;
@property NSMutableDictionary *customer;
@property CommandManager *commandManager;
@property Preferences *preferences;
@property int commandCounter;
@property (nonatomic) BOOL automaticFlushing;
@property NSTimer *flushTimer;
@property UIBackgroundTaskIdentifier task;
@property Session *session;
@property NSDictionary *customSessionProperties;
@property NSString *receipt64;
@property NSObject *lockSessionAccess;
@property NSTimer* timer;
@property (nonatomic) double sessionTimeOut;

@end

@implementation Infinario

- (instancetype)initWithToken:(NSString *)token andWithTarget:(NSString *)target andWithCustomer:(NSMutableDictionary *)customer {
    self = [super init];
    
    self.token = token;
    self.target = target;
    self.sessionTimeOut = SESSION_TIMEOUT;
    
    self.commandManager = [[CommandManager alloc] initWithTarget:self.target andWithToken:self.token];
    self.preferences = [Preferences sharedInstance];
    
    self.customer = nil;
    self.session = nil;
    self.commandCounter = FLUSH_COUNT;
    self.task = UIBackgroundTaskInvalid;
    self.sessionProperties = @{};
    
    _automaticFlushing = [[self.preferences objectForKey:@"automatic_flushing" withDefault:@YES] boolValue];
    
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    
    if (!customer){
        customer = [NSMutableDictionary dictionary];
    }
    
    self.customer = customer;
    self.lockSessionAccess = [[NSObject alloc] init];
    
    if ([[self getAppleAdvertisingId ] isEqualToString:@""]){
        [self initializeAppleAdvertisingId];
    }
    
    return self;
}

+ (id)getInstance:(NSString *)token andWithTarget:(NSString *)target andWithCustomerDict:(NSMutableDictionary *)customer {
    static dispatch_once_t p = 0;
    
    __strong static id _sharedObject = nil;
    
    dispatch_once(&p, ^{
        _sharedObject = [[self alloc] initWithToken:token andWithTarget:target andWithCustomer:customer];
    });
    
    return _sharedObject;
}

+ (id)sharedInstanceWithToken:(NSString *)token andWithTarget:(NSString *)target andWithCustomerDict:(NSMutableDictionary *)customer {
    return [self getInstance:token andWithTarget:target andWithCustomerDict:customer];
}

+ (id)sharedInstanceWithToken:(NSString *)token andWithTarget:(NSString *)target andWithCustomer:(NSString *)customer {
    return [self getInstance:token andWithTarget:target andWithCustomerDict:[self customerDict:customer]];
}

+ (id)sharedInstanceWithToken:(NSString *)token andWithTarget:(NSString *)target {
    return [self getInstance:token andWithTarget:target andWithCustomerDict:nil];
}

+ (id)sharedInstanceWithToken:(NSString *)token andWithCustomerDict:(NSMutableDictionary *)customer {
    return [self getInstance:token andWithTarget:nil andWithCustomerDict:customer];
}

+ (id)sharedInstanceWithToken:(NSString *)token andWithCustomer:(NSString *)customer {
    return [self getInstance:token andWithTarget:nil andWithCustomerDict:[self customerDict:customer]];
}

+ (id)sharedInstanceWithToken:(NSString *)token {
    return [self getInstance:token andWithTarget:nil andWithCustomerDict:nil];
}

+ (id)getInstance:(NSString *)token andWithTarget:(NSString *)target andWithCustomer:(NSString *)customer {
    return [self getInstance:token andWithTarget:target andWithCustomerDict:[self customerDict:customer]];
}

+ (id)getInstance:(NSString *)token andWithTarget:(NSString *)target {
    return [self getInstance:token andWithTarget:target andWithCustomerDict:nil];
}

+ (id)getInstance:(NSString *)token andWithCustomerDict:(NSMutableDictionary *)customer {
    return [self getInstance:token andWithTarget:nil andWithCustomerDict:customer];
}

+ (id)getInstance:(NSString *)token andWithCustomer:(NSString *)customer {
    return [self getInstance:token andWithTarget:nil andWithCustomerDict:[self customerDict:customer]];
}

+ (id)getInstance:(NSString *)token {
    return [self getInstance:token andWithTarget:nil andWithCustomerDict:nil];
}

+ (NSMutableDictionary *)customerDict:(NSString *)customer {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    
    if (customer) {
        dict[@"registered"] = customer;
    }
    
    return dict;
}

- (void)identifyWithCustomerDict:(NSMutableDictionary *)customer andUpdate:(NSDictionary *)properties {
    if (customer[@"registered"] && ![customer[@"registered"] isEqualToString:@""]) {
        NSMutableDictionary *identificationProperties = [Device deviceProperties];
        identificationProperties[@"registered"] = customer[@"registered"];
        [self.customer setObject:customer[@"registered"] forKey:@"registered"];
        
        [self track:@"identification" withProperties:identificationProperties];
        
        if (properties) [self update:properties];
    }
}

- (void)identify:(NSString *)customer andUpdate:(NSDictionary *)properties {
    [self identifyWithCustomerDict:[[self class] customerDict:customer] andUpdate:properties];
}

- (void)identify:(NSString *)customer {
    [self identify:customer andUpdate:nil];
}

- (void)identifyWithCustomer:(NSString *)customer andUpdate:(NSDictionary *)properties {
    [self identifyWithCustomerDict:[[self class] customerDict:customer] andUpdate:properties];
}

- (void)identifyWithCustomerDict:(NSMutableDictionary *)customer {
    [self identifyWithCustomerDict:customer andUpdate:nil];
}

- (void)identifyWithCustomer:(NSString *)customer {
    [self identify:customer andUpdate:nil];
}


- (void)unidentify {
    [self.preferences removeObjectForKey:@"cookie"];
    self.customer = nil;
}

- (void)update:(NSDictionary *)properties {
    Customer *customer = [[Customer alloc] initWithIds:self.customer andProjectId:self.token andWithProperties:properties];
    
    [self.commandManager schedule:customer];
    
    if (self.automaticFlushing) [self setupDelayedFlush];
}

- (void)track:(NSString *)type withProperties:(NSDictionary *)properties withTimestamp:(NSNumber *)timestamp {
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

- (void)trackVirtualPayment:(NSString *)currency withAmount:(NSNumber *)amount withItemName:(NSString *)itemName withItemType:(NSString *)itemType{
    NSMutableDictionary *virtualPayment = [Device deviceProperties];
    
    [virtualPayment setObject:currency forKey:@"currency"];
    [virtualPayment setObject:amount forKey:@"amount"];
    [virtualPayment setObject:itemName forKey:@"item_name"];
    [virtualPayment setObject:itemType forKey:@"item_type"];
    
    [self track:@"virtual_payment" withProperties:virtualPayment];
}

- (void)trackLogDebug:(NSString *)tag withMessage:(NSString *)message{
    [self trackLog:@"log_debug" withTag:tag withMessage:message withProperties:nil];
}

- (void)trackLogDebug:(NSString *)tag withMessage:(NSString *)message withProperties:(NSDictionary *)properties{
    [self trackLog:@"log_debug" withTag:tag withMessage:message withProperties:properties];
}

- (void)trackLogWarning:(NSString *)tag withMessage:(NSString *)message{
    [self trackLog:@"log_warning" withTag:tag withMessage:message withProperties:nil];
}

- (void)trackLogWarning:(NSString *)tag withMessage:(NSString *)message withProperties:(NSDictionary *)properties{
    [self trackLog:@"log_warning" withTag:tag withMessage:message withProperties:properties];
}

- (void)trackLogError:(NSString *)tag withMessage:(NSString *)message{
    [self trackLog:@"log_error" withTag:tag withMessage:message withProperties:nil];
}

- (void)trackLogError:(NSString *)tag withMessage:(NSString *)message withProperties:(NSDictionary *)properties{
    [self trackLog:@"log_error" withTag:tag withMessage:message withProperties:properties];
}

- (void)trackLog:(NSString *)type withTag:(NSString *)tag withMessage:(NSString *)message withProperties:(NSDictionary *)properties{
    NSMutableDictionary *logMessage = [[NSMutableDictionary alloc] init];
    [logMessage setObject:tag forKey:@"tag"];
    [logMessage setObject:message forKey:@"message"];
    if (properties) {
        [logMessage addEntriesFromDictionary:properties];
    }
    
    [self track:type withProperties:logMessage withTimestamp:nil];
}

/*
 * Session's timestamps are saving to preferences to use them after dismiss and reopen app to continue in old session or calculate duration of session.
 */

- (void)sessionStart:(NSNumber *)timestamp {
    [self setSessionValue:@"session_start" withTimeStamp:timestamp];
    
    NSMutableDictionary *properties = [Device deviceProperties];
    [properties addEntriesFromDictionary:self.customSessionProperties];
    
    NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    if (appVersion){
        [properties setObject:appVersion forKey:@"app_version"];
    }
    
    [self track:@"session_start" withProperties:properties withTimestamp:timestamp];
}

- (void)sessionEnd:(NSNumber *)timestamp andWithDuration:(NSNumber *)duration {
    NSMutableDictionary *properties = [Device deviceProperties];
    properties[@"duration"] = duration;
    [properties addEntriesFromDictionary:self.customSessionProperties];
    
    NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    if (appVersion){
        [properties setObject:appVersion forKey:@"app_version"];
    }
    
    [self track:@"session_end" withProperties:properties withTimestamp:timestamp];
    
    [self setSessionValue:@"session_end" withTimeStamp:@-1];
    [self setSessionValue:@"session_start" withTimeStamp:@-1];
}

- (void)trackSessionStart {
    @synchronized(self.lockSessionAccess){
        NSNumber *now = [NSNumber numberWithLong:[[NSDate date] timeIntervalSince1970]];
        NSNumber *sessionEnd = @([[self.preferences objectForKey:@"session_end" withDefault:@-1] intValue]);
        NSNumber *sessionStart = @([[self.preferences objectForKey:@"session_start" withDefault:@-1] intValue]);
        double timeOut = self.sessionTimeOut ? timeOut : SESSION_TIMEOUT;
        
        [self stopTimerEnd];
        
        if (![sessionEnd isEqualToNumber:@-1]){
            if ([now longValue] - [sessionEnd longValue] > timeOut){
                //Create session end
                [self sessionEnd: sessionEnd andWithDuration:[NSNumber numberWithLong:([sessionEnd longValue] - [sessionStart longValue])]];
                //Create session start
                [self sessionStart: now];
            } else {
                //Continue in current session
                [self setSessionValue:@"session_end" withTimeStamp:@-1];
            }
        } else if ([sessionStart isEqualToNumber:@-1]){
            //Create session start
            [self sessionStart: now];
        } else {
            //Continue in current session
        }
    }
}

- (void)trackSessionEnd {
    @synchronized(self.lockSessionAccess){
        //Save session_end with current timestamp and start count TIMOUT
        [self setSessionValue:@"session_end" withTimeStamp:[NSNumber numberWithLong:[[NSDate date] timeIntervalSince1970]]];
        [self startTimerEnd];
    }
}

- (void)startTimerEnd{
    [self stopTimerEnd];
    if (self.sessionTimeOut) {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:self.sessionTimeOut target:self selector:@selector(onTimer:) userInfo:nil repeats:NO];
    } else {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:SESSION_TIMEOUT target:self selector:@selector(onTimer:) userInfo:nil repeats:NO];
    }
    
}

- (void)stopTimerEnd{
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
}

- (void)onTimer:(NSTimer *)timer{
    @synchronized(self.lockSessionAccess){
        NSNumber *sessionEnd = @([[self.preferences objectForKey:@"session_end" withDefault:@-1] intValue]);
        NSNumber *sessionStart = @([[self.preferences objectForKey:@"session_start" withDefault:@-1] intValue]);
        if (![sessionEnd isEqualToNumber:@-1]){
            [self sessionEnd: sessionEnd andWithDuration:[NSNumber numberWithLong:([sessionEnd longValue] - [sessionStart longValue])]];
        }
    }
}

- (void)setSessionValue:(NSString *)session withTimeStamp:(NSNumber *)timestamp{
    [self.preferences setObject:timestamp forKey:session];
}

- (void)setSessionProperties:(NSDictionary *)properties {
    self.customSessionProperties = properties;
}

- (void)setSessionTimeOut:(double)value {
    _sessionTimeOut = value;
}

- (void)flush {
    [self ensureBackgroundTask];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @synchronized(self.commandManager) {
            [self.commandManager flush];
            [self ensureBackgroundTaskFinished];
        }
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
    return [self.preferences objectForKey:@"cookie" withDefault:@""];
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
    NSString *stringToken = [[token description] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
    stringToken = [stringToken stringByReplacingOccurrencesOfString:@" " withString:@""];
    [self update:@{@"apple_push_notification_id": stringToken}];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    for (SKProduct *product in response.products) {
        //NSLog(@"Infinario: tracking hard purchase %@", [product productIdentifier]);
        
        NSMutableDictionary *properties = [Device deviceProperties];
        
        properties[@"gross_amount"] = product.price;
        properties[@"currency"] = [product.priceLocale objectForKey:NSLocaleCurrencyCode];
        properties[@"product_id"] = product.productIdentifier;
        properties[@"product_title"] = product.localizedTitle;
        properties[@"payment_system"] = @"iTunes Store";
        properties[@"receipt"] = self.receipt64;
        
        [self track:@"payment" withProperties:properties];
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    NSMutableSet *products = [NSMutableSet setWithCapacity:transactions.count];
    
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
                //NSLog(@"Infinario: an item has been bought: %@", [[transaction payment] productIdentifier]);
                [products addObject:[[transaction payment] productIdentifier]];
                self.receipt64 = transaction.transactionReceipt.base64Encoding;
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
                
            case SKPaymentTransactionStateFailed:
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
                
            default:
                break;
        }
    }
    
    if (products.count > 0 && [SKPaymentQueue canMakePayments]) {
        SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:products];
        request.delegate = self;
        [request start];
    }
}

- (NSString *)getAppleAdvertisingId{
    return [self.preferences objectForKey:@"apple_advertising_id" withDefault:@""];
}

- (void)initializeAppleAdvertisingId{
    NSString *advertisingId =[[ASIdentifierManager sharedManager].advertisingIdentifier UUIDString];
    
    [self.preferences setObject:advertisingId forKey:@"apple_advertising_id"];
    
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    [properties setObject:advertisingId forKey:@"apple_advertising_id"];
    
    [self update:properties];
}

- (void)getCurrentSegment:(NSString *)segmentationId withProjectSecret:(NSString *)projectSecretToken withCallBack:(onSegmentReceive)callback{
    @try {
        NSString *target = self.target ? target : @"https://api.infinario.com";
        
        if ([target hasPrefix:@"https"]) {
            
            NSMutableDictionary *body = [NSMutableDictionary dictionary];
            NSMutableDictionary *ids = [NSMutableDictionary dictionary];
    
            [ids setObject:[self.preferences objectForKey:@"cookie" withDefault:@""] forKey:@"cookie"];
            [ids setObject:[self.preferences objectForKey:@"registered" withDefault:@""] forKey:@"registered"];
    
            [body setObject:ids forKey:@"customer_ids"];
            [body setObject:segmentationId forKey:@"analysis_id"];
    
            NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", target, @"/analytics/segmentation-for"]]];
    
            [request setHTTPMethod:@"POST"];
            [request setValue:@"application/json" forHTTPHeaderField:@"Content-type"];
            [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
            [request setValue:projectSecretToken forHTTPHeaderField:@"X-Infinario-Secret"];
    
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    
            [request setValue:[NSString stringWithFormat:@"%d", (int) [jsonData length]] forHTTPHeaderField:@"Content-length"];
            [request setHTTPBody:jsonData];
    
            NSOperationQueue *queue = [[NSOperationQueue alloc]init];
            [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error){
                                   if (error) {
                                       callback(false, nil, @"Null response");
                                   } else {
                                       NSError* error;
                                       NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
 
                                       if (error == nil){
                                           callback(true, [[InfinarioSegment alloc] initWithName:[json objectForKey:@"segment"]], nil);
                                       } else {
                                           callback(false, nil, @"Unsucesfull response");
                                       }
                                   }
            }];
        } else {
            callback(false, nil, @"Target must be https");
        }
        
    }
    @catch ( NSException *e ) {
       NSLog(@"%@", e.reason);
       callback(false, nil, e.reason);
    }
}

@end
