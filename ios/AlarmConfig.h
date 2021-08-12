//
//  AlarmConfig.h
//  
//
//  Created by Guilherme Hashioka on 12/08/21.
//

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

NS_ASSUME_NONNULL_BEGIN

@interface AlarmConfig : NSObject

@property (readonly) NSString * title;
@property (readonly) NSString * body;
@property (readonly) NSString * alarmId;
@property (readonly) NSNumber * playSound;
@property (readonly) NSNumber * vibrate;
@property (readonly) NSString * data;
@property (readonly) NSString * fireDate;
@property (readonly) NSString * soundName;
@property (readonly) NSNumber * loopSound;
@property (readonly) NSString * volume;
@property (readonly) NSNumber * hasButton;
@property (readonly) NSString * scheduleType;
@property (readonly) NSString * repeatInterval;
@property (readonly) NSNumber * intervalValue;
@property (readonly) NSString * snoozeInterval;

- (id) initWitAlarmId: (NSString *) alarmId dictionary:(NSDictionary *) details;
- (id) initWitAlarmId: (NSString *) alarmId  notification:(UNNotification *) notification;

- (NSDictionary *)dictionary;
- (NSDateComponents *) fireDateComponents;

@end

NS_ASSUME_NONNULL_END
