#import "RnAlarmNotification.h"
#import "AlarmConfig.h"

#import <UserNotifications/UserNotifications.h>

#import <React/RCTBridge.h>
#import <React/RCTConvert.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTUtils.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

static NSString *const kLocalNotificationReceived = @"LocalNotificationReceived";
static NSString *const kLocalNotificationDismissed = @"LocalNotificationDismissed";
static NSString *const kLocalNotificationStarted = @"LocalNotificationStarted";

static id _sharedInstance = nil;

@implementation RnAlarmNotification

bool hasListeners;
AVAudioPlayer *player;
MPVolumeView *volumeView;
UISlider *volumeSlider;

+(instancetype)sharedInstance {
    static dispatch_once_t p;
    dispatch_once(&p, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}


-(instancetype)init{
    self = [super init];
    [self initVolumeView];

    return self;
}

#pragma mark - Volume config

-(void)initVolumeView{
    volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(-[UIScreen mainScreen].bounds.size.width, 0, 0, 0)];
    [self showVolumeUI:YES];
    for (UIView* view in volumeView.subviews) {
        if ([view.class.description isEqualToString:@"MPVolumeSlider"]){
            volumeSlider = (UISlider*)view;
            break;
        }
    }
}

-(void)showVolumeUI:(BOOL)flag{
    if(flag && [volumeView superview]){
        [volumeView removeFromSuperview];
    }else if(!flag && ![volumeView superview]){
        [[[[UIApplication sharedApplication] keyWindow] rootViewController].view addSubview:volumeView];
    }
}

-(void)setVolume:(float)val showingUI:(BOOL)showUI {
    [self showVolumeUI:showUI];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        volumeSlider.value = val;
    });
}

#pragma mark - utils
API_AVAILABLE(ios(10.0))
static NSDictionary *RCTFormatUNNotification(UNNotification *notification) {
    NSMutableDictionary *formattedNotification = [NSMutableDictionary dictionary];
    UNNotificationContent *content = notification.request.content;

    formattedNotification[@"id"] = notification.request.identifier;
    formattedNotification[@"data"] = RCTNullIfNil([content.userInfo objectForKey:@"data"]);

    return formattedNotification;
}

static NSDateComponents *parseDate(NSString *dateString) {
    NSArray *fire_date = [dateString componentsSeparatedByString:@" "];
    NSString *date = fire_date[0];
    NSString *time = fire_date[1];
    
    NSArray *splitDate = [date componentsSeparatedByString:@"-"];
    NSArray *splitHour = [time componentsSeparatedByString:@":"];
    
    NSString *strNumDay = splitDate[0];
    NSString *strNumMonth = splitDate[1];
    NSString *strNumYear = splitDate[2];
    
    NSString *strNumHour = splitHour[0];
    NSString *strNumMinute = splitHour[1];
    NSString *strNumSecond = splitHour[2];
    
    // Configure the trigger for date
    NSDateComponents *fireDate = [[NSDateComponents alloc] init];
    fireDate.day = [strNumDay intValue];
    fireDate.month = [strNumMonth intValue];
    fireDate.year = [strNumYear intValue];
    fireDate.hour = [strNumHour intValue];
    fireDate.minute = [strNumMinute intValue];
    fireDate.second = [strNumSecond intValue];
    fireDate.timeZone = [NSTimeZone defaultTimeZone];
    
    return fireDate;
}

static NSDateComponents *dateToComponents(NSDate *date) {
    NSDateComponents *fireDate = [[NSDateComponents alloc] init];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    
    [formatter setDateFormat:@"yyyy"];
    NSString *year = [formatter stringFromDate:date];
    
    [formatter setDateFormat:@"MM"];
    NSString *month = [formatter stringFromDate:date];
    
    [formatter setDateFormat:@"dd"];
    NSString *day = [formatter stringFromDate:date];
    
    [formatter setDateFormat:@"HH"];
    NSString *hour = [formatter stringFromDate:date];
    
    [formatter setDateFormat:@"mm"];
    NSString *minute = [formatter stringFromDate:date];
    
    [formatter setDateFormat:@"ss"];
    NSString *second = [formatter stringFromDate:date];
    
    fireDate.day = [day intValue];
    fireDate.month = [month intValue];
    fireDate.year = [year intValue];
    fireDate.hour = [hour intValue];
    fireDate.minute = [minute intValue];
    fireDate.second = [second intValue];
    fireDate.timeZone = [NSTimeZone defaultTimeZone];
    
    return fireDate;
}

static NSString *stringify(NSDictionary *notification) {
    if (![NSJSONSerialization isValidJSONObject:notification]) {
        return @"invalid json";
    }

    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:notification options:0 error:&error];
    
    if (! jsonData) {
        NSLog(@"Got an error: %@", error);
        return @"bad json";
    } else {
        NSString * jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        
        return jsonString;
    }
}

API_AVAILABLE(ios(10.0))
static inline NSDictionary *RCTPromiseResolveValueForUNNotificationSettings(UNNotificationSettings* _Nonnull settings) {
    return RCTSettingsDictForUNNotificationSettings(settings.alertSetting == UNNotificationSettingEnabled, settings.badgeSetting == UNNotificationSettingEnabled, settings.soundSetting == UNNotificationSettingEnabled, settings.lockScreenSetting == UNNotificationSettingEnabled, settings.notificationCenterSetting == UNNotificationSettingEnabled);
}

static inline NSDictionary *RCTSettingsDictForUNNotificationSettings(BOOL alert, BOOL badge, BOOL sound, BOOL lockScreen, BOOL notificationCenter) {
    return @{@"alert": @(alert), @"badge": @(badge), @"sound": @(sound), @"lockScreen": @(lockScreen), @"notificationCenter": @(notificationCenter)};
}

API_AVAILABLE(ios(10.0))
static NSDictionary *RCTFormatUNNotificationRequest(UNNotificationRequest *request)
{
    NSMutableDictionary *formattedNotification = [NSMutableDictionary dictionary];
    UNNotificationContent *content = request.content;
    
    NSDateComponents *fireDate = parseDate(content.userInfo[@"fire_date"]);

    formattedNotification[@"id"] = request.identifier;
    formattedNotification[@"day"] = [NSString stringWithFormat:@"%li", (long)fireDate.day];
    formattedNotification[@"month"] = [NSString stringWithFormat:@"%li", (long)fireDate.month];
    formattedNotification[@"year"] = [NSString stringWithFormat:@"%li", (long)fireDate.year];
    formattedNotification[@"hour"] = [NSString stringWithFormat:@"%li", (long)fireDate.hour];
    formattedNotification[@"minute"] =[NSString stringWithFormat:@"%li", (long)fireDate.minute];
    formattedNotification[@"second"] = [NSString stringWithFormat:@"%li", (long)fireDate.second];

    return formattedNotification;
}

- (dispatch_queue_t)methodQueue {
    return dispatch_get_main_queue();
}

RCT_EXPORT_MODULE(RNAlarmNotification);

#pragma mark - RNAlarmNotification
- (void)vibratePhone {
    NSLog(@"vibratePhone %@", @"here");
    if([[UIDevice currentDevice].model isEqualToString:@"iPhone"]) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    } else {
        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
    }
}

- (void) didReceiveNotification:(UNNotification *)notification  API_AVAILABLE(ios(10.0)){
    AlarmConfig *alarmConfig = [[AlarmConfig alloc] initWitAlarmId:notification.request.identifier notification:notification];
    NSLog(@"content: %@", alarmConfig.dictionary);

    NSNumber *vibrate = alarmConfig.vibrate;
    if([vibrate isEqualToNumber: [NSNumber numberWithInt: 1]]){
        NSLog(@"do vibrate now");
        [self vibratePhone];
    }

    NSString *scheduleType = alarmConfig.scheduleType;
    if([scheduleType isEqualToString:@"repeat"]){
        [self repeatAlarm:notification];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:kLocalNotificationStarted
                                                    object:self
                                                    userInfo:RCTFormatUNNotification(notification)];
}

- (void)didReceiveNotificationResponse:(UNNotificationResponse *)response
API_AVAILABLE(ios(10.0)) {
    NSLog(@"show notification");
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    if ([response.notification.request.content.categoryIdentifier isEqualToString:@"CUSTOM_ACTIONS"]) {
       if ([response.actionIdentifier isEqualToString:@"SNOOZE_ACTION"]) {
           [self snoozeAlarm:response.notification];
       } else if ([response.actionIdentifier isEqualToString:@"DISMISS_ACTION"]) {
           NSLog(@"do dismiss");
           [self stopSound];
           
           NSMutableDictionary *notification = [NSMutableDictionary dictionary];
           notification[@"id"] = response.notification.request.identifier;
           
           [[NSNotificationCenter defaultCenter] postNotificationName:kLocalNotificationDismissed
                                                               object:self
                                                             userInfo:notification];
       }
    }
    
    // send notification
    [[NSNotificationCenter defaultCenter] postNotificationName:kLocalNotificationReceived
                                                        object:self
                                                      userInfo:RCTFormatUNNotification(response.notification)];
}

// Will be called when this module's first listener is added.
- (void)startObserving {
    NSLog(@"RnAlarmNotification ~ startObserving");
    hasListeners = YES;

    // receive notification
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleLocalNotificationReceived:) name:kLocalNotificationReceived
                                               object:nil];
    
    // dismiss notification
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleLocalNotificationDismissed:) name:kLocalNotificationDismissed
                                               object:nil];

    // start notification
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleLocalNotificationStarted:) name:kLocalNotificationStarted
                                               object:nil];
}

// Will be called when this module's last listener is removed, or on dealloc.
- (void)stopObserving {
    NSLog(@"RnAlarmNotification ~ stopObserving");
    hasListeners = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSArray<NSString *> *)supportedEvents {
    return @[@"OnNotificationOpened", @"OnNotificationStarted", @"OnNotificationDismissed"];
}

- (void)handleLocalNotificationReceived:(NSNotification *)notification {
    NSLog(@"RnAlarmNotification ~ handleLocalNotificationReceived - %@", hasListeners ? @"true" : @"false");
    // send to js
    if (hasListeners) { 
        [self sendEventWithName:@"OnNotificationOpened" body: stringify(notification.userInfo)];
    }
}

- (void)handleLocalNotificationDismissed:(NSNotification *)notification {
    NSLog(@"RnAlarmNotification ~ handleLocalNotificationDismissed - %@", hasListeners ? @"true" : @"false");
    // send to js
    if (hasListeners) { 
        [self sendEventWithName:@"OnNotificationDismissed" body: stringify(notification.userInfo)];
    }
}

- (void)handleLocalNotificationStarted:(NSNotification *)notification {
    NSLog(@"RnAlarmNotification ~ handleLocalNotificationStarted - %@", hasListeners ? @"true" : @"false");
    // send to js
    if (hasListeners) { 
        [self sendEventWithName:@"OnNotificationStarted" body: stringify(notification.userInfo)];
    }
}

- (void)stopSound {
    @try {
        if (player) {
            [player stop];
            player.currentTime = 0;
        }
    } @catch(NSException *exception){
        NSLog(@"%@", exception.reason);
    }
}

- (void)repeatAlarm:(UNNotification *)notification  API_AVAILABLE(ios(10.0)) {
    [self stopSound];
    
    @try {
        if (@available(iOS 10.0, *)) {
            NSString *alarmId = [notification.request.content.userInfo objectForKey:@"alarmId"];
            AlarmConfig *alarmConfig = [[AlarmConfig alloc] initWitAlarmId:alarmId notification:notification];
            
            // alarm date
            NSDateComponents *fireDate = alarmConfig.fireDateComponents;
            NSString *repeatInterval = alarmConfig.repeatInterval;
            NSNumber *intervalValue = alarmConfig.intervalValue;
            NSLog(@"schedule repeat interval %@", repeatInterval);
            if([repeatInterval isEqualToString:@"minutely"]){
                fireDate.minute = fireDate.minute + [intervalValue intValue];
            } else if([repeatInterval isEqualToString:@"hourly"]) {
                fireDate.hour = fireDate.hour + [intervalValue intValue];
            } else if([repeatInterval isEqualToString:@"daily"]) {
                fireDate.day = fireDate.day + 1;
            } else if([repeatInterval isEqualToString:@"weekly"]) {
                fireDate.weekday = fireDate.weekday + 1;
            }
            NSLog(@"------ next fire date: %@", fireDate);
            // date to string
            NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
            NSDate *dateString = [gregorianCalendar dateFromComponents:fireDate];
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"dd-MM-yyyy HH:mm:ss"];
            NSString *stringFromDate = [formatter stringFromDate:dateString];
            NSLog(@"%@", stringFromDate);
            UNCalendarNotificationTrigger* trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:fireDate repeats:NO];
            
            NSLog(@"schedule type: %@", alarmConfig.scheduleType);
            
            NSDictionary * alarm = [self scheduleAlarmWithConfig:alarmConfig trigger:trigger];
            NSLog(@"repeat alarm: %@", alarm);
        } else {
            // Fallback on earlier versions
        }
    } @catch(NSException *exception){
        NSLog(@"error: %@", exception.reason);
    }
}

- (void)snoozeAlarm:(UNNotification *)notification  API_AVAILABLE(ios(10.0)) {
    NSLog(@"do snooze");
    [self stopSound];
    
    @try {
        if (@available(iOS 10.0, *)) {
            NSString *alarmId = [NSString stringWithFormat: @"%ld", (long) NSDate.date.timeIntervalSince1970];
            AlarmConfig *alarmConfig = [[AlarmConfig alloc] initWitAlarmId:alarmId notification:notification];
            
            // set alarm date
            NSTimeInterval snoozeInterval = [alarmConfig.snoozeInterval intValue] * 60;
            NSDate *now = [NSDate date];
            NSDate *newDate = [now dateByAddingTimeInterval:snoozeInterval];
            NSLog(@"new fire date after snooze: %@", newDate);
            NSDateComponents *newFireDate = dateToComponents(newDate);
            UNCalendarNotificationTrigger* trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:newFireDate repeats:NO];
            
            NSDictionary * alarm = [self scheduleAlarmWithConfig:alarmConfig trigger:trigger];
            
            NSLog(@"snooze alarm: %@", alarm);
        } else {
            // Fallback on earlier versions
        }
    } @catch(NSException *exception){
        NSLog(@"error: %@", exception.reason);
    }
}

+ (BOOL) checkStringIsNotEmpty:(NSString*)string {
    if (string == (id)[NSNull null] || string.length == 0) return NO;
    return YES;
}

- (NSDictionary *)scheduleAlarmWithConfig:(AlarmConfig *)alarmConfig trigger:(UNCalendarNotificationTrigger *)trigger  API_AVAILABLE(ios(10.0)){
    /// SOUND
    NSString *soundName = alarmConfig.soundName;
    NSNumber *loopSound = alarmConfig.loopSound;
    NSString *volume = alarmConfig.volume;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback
             withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker
                   error:nil];
    [session setActive:true error:nil];
    [session setMode:AVAudioSessionModeDefault error:nil]; // optional
    NSError *playerError = nil;
    NSLog(@"### SOUND");
    
    if([RnAlarmNotification checkStringIsNotEmpty:soundName]){
        NSLog(@"soundName: %@", soundName);

        NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:soundName];

        NSString* soundPathEscaped = [path stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSURL *soundUri = [NSURL URLWithString:soundPathEscaped];

        NSLog(@"sound path: %@", soundUri);

        if(player){
            [player stop];
            player = nil;
        }

        player = [[AVAudioPlayer alloc] initWithContentsOfURL:soundUri
                                                        error:&playerError];

        if(playerError) {
            NSLog(@"[AppDelegate] audioPlayerError: %@", playerError);
        } else if (player){
            @synchronized(self){
                player.delegate = (id<AVAudioPlayerDelegate>)self;;
                player.enableRate = YES;
                [player prepareToPlay];

                NSLog(@"sound volume: %@", RCTNullIfNil(volume));
                // set volume
                player.volume = [volume floatValue];

                NSLog(@"sound loop: %@", loopSound);
                // enable/disable loop
                if ([loopSound isEqualToNumber: [NSNumber numberWithInt: 1]]) {
                    player.numberOfLoops = -1;
                } else {
                    player.numberOfLoops = 0;
                }

                [self setVolume: [volume floatValue] showingUI:true];

                NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
                
                NSDateComponents *fireDate = trigger.dateComponents;
                if (fireDate) {
                    NSTimeInterval interval = [[calendar dateFromComponents:fireDate] timeIntervalSinceNow];
                    NSLog(@"fireDate: %@ %g", fireDate, interval);
                    [player playAtTime: [player deviceCurrentTime] + interval];
                } else {
                    [player play];
                }
            }
        }
    }
    
    
    
    /// NOTIFICATION
    NSLog(@"### NOTIFICATION");
    UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
    
    content.title = alarmConfig.title;
    content.body = alarmConfig.body;
    content.userInfo = alarmConfig.dictionary;
    
    // set buttons
    NSNumber *hasButton = alarmConfig.hasButton;
    if([hasButton isEqualToNumber: [NSNumber numberWithInt: 1]]){
        content.categoryIdentifier = @"CUSTOM_ACTIONS";
    }
    
    NSNumber *playSound = alarmConfig.playSound;
    if([playSound isEqualToNumber: [NSNumber numberWithInt: 1]]) {
        BOOL notEmpty = [RnAlarmNotification checkStringIsNotEmpty:soundName];
        if(notEmpty != YES){
            content.sound = UNNotificationSound.defaultSound;
        }
    }
    
    // Create the request object.
    UNNotificationRequest* request = [UNNotificationRequest requestWithIdentifier:alarmConfig.alarmId content:content trigger:trigger];
    
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    
    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"error: %@", error.localizedDescription);
        }
    }];
    
    NSDictionary *alarm = [NSDictionary dictionaryWithObjectsAndKeys: alarmConfig.alarmId, @"id", nil];
    return alarm;
}

RCT_EXPORT_METHOD(scheduleAlarm: (NSDictionary *)details resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject){
    @try {
        if (@available(iOS 10.0, *)) {
            NSString *alarmId = [NSString stringWithFormat: @"%ld", (long) NSDate.date.timeIntervalSince1970];
            AlarmConfig *alarmConfig = [[AlarmConfig alloc] initWitAlarmId:alarmId dictionary:details];
            
            NSDateComponents *fireDate = alarmConfig.fireDateComponents;
            UNCalendarNotificationTrigger* trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:fireDate repeats:NO];
            NSDictionary * alarm = [self scheduleAlarmWithConfig:alarmConfig trigger:trigger];
            resolve(alarm);
        } else {
            // Fallback on earlier versions
        }
    } @catch(NSException *exception){
        NSLog(@"%@", exception.reason);
        NSMutableDictionary * info = [NSMutableDictionary dictionary];
        [info setValue:exception.name forKey:@"ExceptionName"];
        [info setValue:exception.reason forKey:@"ExceptionReason"];
        [info setValue:exception.callStackSymbols forKey:@"ExceptionCallStackSymbols"];
        [info setValue:exception.userInfo forKey:@"ExceptionUserInfo"];

        NSError *error = [[NSError alloc] initWithDomain:exception.name code:0 userInfo:info];
        reject(@"error", nil, error);
    }
    
}

RCT_EXPORT_METHOD(sendNotification: (NSDictionary *)details) {
    @try {
        NSLog(@"send notification now");
        if (@available(iOS 10.0, *)) {
            NSString *alarmId = [NSString stringWithFormat: @"%ld", (long) NSDate.date.timeIntervalSince1970];
            AlarmConfig *alarmConfig = [[AlarmConfig alloc] initWitAlarmId:alarmId dictionary:details];
            [self scheduleAlarmWithConfig:alarmConfig trigger:nil];
        } else {
            // Fallback on earlier versions
        }
    } @catch(NSException *exception){
        NSLog(@"error: %@", exception.reason);
    }
}

RCT_EXPORT_METHOD(deleteAlarm: (NSInteger *)id){
    NSLog(@"delete alarm: %li", (long) id);
    if (@available(iOS 10.0, *)) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        NSArray *array = [NSArray arrayWithObjects:[NSString stringWithFormat:@"%li", (long)id], nil];
        [center removePendingNotificationRequestsWithIdentifiers:array];
    } else {
        // Fallback on earlier versions
    }
}

RCT_EXPORT_METHOD(deleteRepeatingAlarm: (NSInteger *)id){
    NSLog(@"delete alarm: %li", (long) id);
    if (@available(iOS 10.0, *)) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        NSArray *array = [NSArray arrayWithObjects:[NSString stringWithFormat:@"%li", (long)id], nil];
        [center removePendingNotificationRequestsWithIdentifiers:array];
    } else {
        // Fallback on earlier versions
    }
}

RCT_EXPORT_METHOD(stopAlarmSound){
    NSLog(@"stop alarm sound");
    [self stopSound];
}

RCT_EXPORT_METHOD(removeFiredNotification: (NSInteger)id){
    NSLog(@"remove fired notification: %li", (long) id);
    if (@available(iOS 10.0, *)) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        NSArray *array = [NSArray arrayWithObjects:[NSString stringWithFormat:@"%li", (long)id], nil];
        [center removeDeliveredNotificationsWithIdentifiers:array];
    } else {
        // Fallback on earlier versions
    }
}

RCT_EXPORT_METHOD(removeAllFiredNotifications){
    NSLog(@"remove all notifications");
    if (@available(iOS 10.0, *)) {
        if ([UNUserNotificationCenter class]) {
            UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
            [center removeAllDeliveredNotifications];
        }
    } else {
        // Fallback on earlier versions
    }
}


RCT_EXPORT_METHOD(getScheduledAlarms: (RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject){
    NSLog(@"get all notifications");
    if (@available(iOS 10.0, *)) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        
        [center getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> * _Nonnull requests) {
            NSLog(@"count%lu",(unsigned long)requests.count);
            
            NSMutableArray<NSDictionary *> *formattedNotifications = [NSMutableArray new];
            
            for (UNNotificationRequest *request in requests) {
                [formattedNotifications addObject:RCTFormatUNNotificationRequest(request)];
            }
            resolve(formattedNotifications);
        }];
    } else {
        resolve(nil);
    }
}

RCT_EXPORT_METHOD(isAlarmPlaying: (RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject){
    NSNumber * result = [NSNumber numberWithBool:[player isPlaying]];
    resolve(result);
}

RCT_EXPORT_METHOD(requestPermissions:(NSDictionary *)permissions
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    if (RCTRunningInAppExtension()) {
        reject(@"E_UNABLE_TO_REQUEST_PERMISSIONS", nil, RCTErrorWithMessage(@"Requesting push notifications is currently unavailable in an app extension"));
        return;
    }
    
    UIUserNotificationType types = UIUserNotificationTypeNone;
    if (permissions) {
        if ([RCTConvert BOOL:permissions[@"alert"]]) {
            types |= UIUserNotificationTypeAlert;
        }
        if ([RCTConvert BOOL:permissions[@"badge"]]) {
            types |= UIUserNotificationTypeBadge;
        }
        if ([RCTConvert BOOL:permissions[@"sound"]]) {
            types |= UIUserNotificationTypeSound;
        }
    } else {
        types = UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound;
    }
    
    if (@available(iOS 10.0, *)) {
        UNNotificationCategory* generalCategory = [UNNotificationCategory
            categoryWithIdentifier:@"GENERAL"
            actions:@[]
            intentIdentifiers:@[]
            options:UNNotificationCategoryOptionCustomDismissAction];
        
        UNNotificationAction* snoozeAction = [UNNotificationAction
              actionWithIdentifier:@"SNOOZE_ACTION"
              title:@"SNOOZE"
              options:UNNotificationActionOptionNone];
         
        UNNotificationAction* stopAction = [UNNotificationAction
              actionWithIdentifier:@"DISMISS_ACTION"
              title:@"DISMISS"
              options:UNNotificationActionOptionForeground];
        
        UNNotificationCategory* customCategory = [UNNotificationCategory
            categoryWithIdentifier:@"CUSTOM_ACTIONS"
            actions:@[snoozeAction, stopAction]
            intentIdentifiers:@[]
            options:UNNotificationCategoryOptionNone];
        
        UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
        
        [center setNotificationCategories:[NSSet setWithObjects:generalCategory, customCategory, nil]];
        
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert + UIUserNotificationTypeBadge + UNAuthorizationOptionSound) completionHandler:^(BOOL granted, NSError *_Nullable error) {
            
            if (error != NULL) {
                reject(@"-1", @"Error - Push authorization request failed.", error);
            } else {
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    [RCTSharedApplication() registerForRemoteNotifications];
                });
                [UNUserNotificationCenter.currentNotificationCenter getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
                    resolve(RCTPromiseResolveValueForUNNotificationSettings(settings));
                }];
            }
        }];
    } else {
        // Fallback on earlier versions
        resolve(nil);
    }
}

RCT_EXPORT_METHOD(checkPermissions:(RCTResponseSenderBlock)callback) {
    if (RCTRunningInAppExtension()) {
        callback(@[RCTSettingsDictForUNNotificationSettings(NO, NO, NO, NO, NO)]);
        return;
    }
    
    if (@available(iOS 10.0, *)) {
        [UNUserNotificationCenter.currentNotificationCenter getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
            callback(@[RCTPromiseResolveValueForUNNotificationSettings(settings)]);
        }];
    } else {
        // Fallback on earlier versions
    }
}


RCT_EXPORT_METHOD(playAlarmWithId: (NSInteger *)alarmId){
    NSLog(@"play alarm: %li", (long) alarmId);
    
    if (@available(iOS 10.0, *)) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> * _Nonnull requests) {
            NSPredicate *predicate = [NSPredicate
                                      predicateWithFormat:@"identifier == %@",
                                      [NSString stringWithFormat:@"%i", alarmId]
            ];
          
            NSArray *filteredArray = [requests filteredArrayUsingPredicate:predicate];
            UNNotificationRequest* firstFoundObject = nil;
            firstFoundObject =  filteredArray.count > 0 ? filteredArray.firstObject : nil;

            if (!firstFoundObject) {
                return;
            }
            
            // send notification now
            NSMutableDictionary *notification = [NSMutableDictionary dictionaryWithDictionary:firstFoundObject.content.userInfo];
            [notification setValue:firstFoundObject.content.title forKey:@"title"];
            [notification setValue:firstFoundObject.content.body forKey:@"message"];
            [notification setValue:@([firstFoundObject.content.userInfo[@"volume"] floatValue])  forKey:@"volume"];
            [notification setValue:nil forKey:@"fire_date"];
            [self sendNotification:notification];
            
            [self deleteAlarm: alarmId];
        }];
    } else {
        // Fallback on earlier versions
    }
}

@end
