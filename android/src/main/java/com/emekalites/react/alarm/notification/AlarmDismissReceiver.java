package com.emekalites.react.alarm.notification;

import android.app.Application;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.google.gson.Gson;


public class AlarmDismissReceiver extends BroadcastReceiver {
    private static final String TAG = AlarmDismissReceiver.class.getSimpleName();

    @Override
    public void onReceive(Context context, Intent intent) {
        AlarmUtil alarmUtil = new AlarmUtil((Application) context.getApplicationContext());
        try {
            if (ANModule.getReactAppContext() != null) {
                int notificationId = intent.getExtras().getInt(Constants.DISMISSED_NOTIFICATION_ID);

                ReactApplicationContext reactContext = ANModule.getReactAppContext();
                if (reactContext != null) {
                    reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class).emit("OnNotificationDismissed", "{\"id\": \"" + notificationId + "\"}");
                }

                alarmUtil.removeFiredNotification(notificationId);

                alarmUtil.doCancelAlarm(notificationId);
            }
        } catch (Exception e) {
            alarmUtil.stopAlarmSound();
            System.err.println("Exception when handling notification dismiss. " + e);
        }
    }
}
