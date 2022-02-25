//
//  AlarmConfig.m
//  
//

#import "AlarmConfig.h"


@interface AlarmConfig ()

@property NSString * title;
@property NSString * body;
@property NSString * alarmId;
@property NSNumber * playSound;
@property NSNumber * vibrate;
@property NSString * data;
@property NSString * fireDate;
@property NSString * soundName;
@property NSNumber * loopSound;
@property NSString * volume;
@property NSNumber * hasButton;
@property NSString * scheduleType;
@property NSString * repeatInterval;
@property NSNumber * intervalValue;
@property NSString * snoozeInterval;

@end

@implementation AlarmConfig

- (id) initWitAlarmId: (NSString *) alarmId dictionary:(NSDictionary *) details {
    self = [super init];
    if (self) {
        if (@available(iOS 10.0, *)) {
            NSString *title = [NSString localizedUserNotificationStringForKey:details[@"title"] arguments:nil];
            NSString *body = [NSString localizedUserNotificationStringForKey:details[@"message"] arguments:nil];
            [self setTitle:title];
            [self setBody:body];
        }
        
        NSString *scheduleType = details[@"schedule_type"];
        NSNumber *hasButton = details[@"has_button"];
        NSString *fireDate = details[@"fire_date"];
        NSString *repeatInterval = details[@"repeat_interval"];
        NSNumber *intervalValue = details[@"interval_value"];
        NSString *soundName = details[@"sound_name"];
        NSNumber *playSound = details[@"play_sound"];
        NSNumber* vibrate = details[@"vibrate"];
        NSString* data = details[@"data"];
        NSNumber* loopSound = details[@"loop_sound"];
        NSString *volume = [details[@"volume"] stringValue];
        NSString* snoozeInterval = details[@"snooze_interval"];
        
        [self setAlarmId:alarmId];
        [self setScheduleType:scheduleType];
        [self setHasButton:hasButton];
        [self setFireDate:fireDate];
        [self setRepeatInterval:repeatInterval];
        [self setIntervalValue:intervalValue];
        [self setAlarmId:alarmId];
        [self setData:data];
        [self setSoundName:soundName];
        [self setPlaySound:playSound];
        [self setVibrate:vibrate];
        [self setLoopSound:loopSound];
        [self setVolume:volume];
        [self setSnoozeInterval:snoozeInterval];
    }
    return self;
}

- (id) initWitAlarmId: (NSString *) alarmId  notification:(UNNotification *) notification API_AVAILABLE(ios(10.0)) {
    self = [super init];
    if (self) {
        UNNotificationContent *contentInfo = notification.request.content;
        NSDictionary* userInfo = contentInfo.userInfo;
        
        NSString *title = contentInfo.title;
        NSString *body = contentInfo.body;
        NSString *scheduleType = [userInfo objectForKey:@"schedule_type"];
        NSNumber *hasButton = [userInfo objectForKey:@"has_button"];
        NSString *fireDate = [userInfo objectForKey:@"fireDate"];
        NSString *repeatInterval = [userInfo objectForKey:@"repeat_interval"];
        NSNumber *intervalValue = [userInfo objectForKey:@"interval_value"];
        NSString *soundName = [userInfo objectForKey:@"sound_name"];
        NSNumber *playSound = [userInfo objectForKey:@"sound"];
        NSNumber* vibrate = [userInfo objectForKey:@"vibrate"];
        NSString* data = [userInfo objectForKey:@"data"];
        NSNumber* loopSound = [userInfo objectForKey:@"loop_sound"];
        NSString* volume = [userInfo objectForKey:@"volume"];
        NSString* snoozeInterval = [userInfo objectForKey:@"snooze_interval"];

        [self setAlarmId:alarmId];
        [self setTitle:title];
        [self setBody:body];
        [self setScheduleType:scheduleType];
        [self setHasButton:hasButton];
        [self setFireDate:fireDate];
        [self setRepeatInterval:repeatInterval];
        [self setIntervalValue:intervalValue];
        [self setAlarmId:alarmId];
        [self setData:data];
        [self setSoundName:soundName];
        [self setPlaySound:playSound];
        [self setVibrate:vibrate];
        [self setLoopSound:loopSound];
        [self setVolume:volume];
        [self setSnoozeInterval:snoozeInterval];
    }
    return self;
}

- (NSDictionary *)dictionary {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    dictionary[@"alarmId"]         = [self alarmId];
    dictionary[@"play_sound"]      = [self playSound];
    dictionary[@"vibrate"]         = [self vibrate];
    dictionary[@"data"]            = [self data];
    dictionary[@"fire_date"]       = [self fireDate];
    dictionary[@"sound_name"]      = [self soundName];
    dictionary[@"loop_sound"]      = [self loopSound];
    dictionary[@"volume"]          = [self volume];
    dictionary[@"has_button"]      = [self hasButton];
    dictionary[@"schedule_type"]   = [self scheduleType];
    dictionary[@"repeat_interval"] = [self repeatInterval];
    dictionary[@"interval_value"]  = [self intervalValue];
    dictionary[@"snooze_interval"] = [self snoozeInterval];
    return dictionary;
}

- (NSDateComponents *)fireDateComponents {
    return self.fireDate ? [self parseDate:self.fireDate] : nil;
}

- (NSDateComponents *)parseDate:(NSString *)dateString {
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

@end
