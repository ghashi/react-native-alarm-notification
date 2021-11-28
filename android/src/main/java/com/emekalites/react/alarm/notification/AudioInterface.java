package com.emekalites.react.alarm.notification;

import android.content.Context;
import android.media.AudioAttributes;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

class AudioInterface {
    private static final String TAG = AudioInterface.class.getSimpleName();

    private static MediaPlayer player;
    
    private static AudioInterface ourInstance = new AudioInterface();
    private Context mContext;
    private Uri uri;

    private AudioInterface() {
    }

    private static Context get() {
        return getInstance().getContext();
    }

    static synchronized AudioInterface getInstance() {
        return ourInstance;
    }

    void init(Context context) {
        uri = Settings.System.DEFAULT_ALARM_ALERT_URI;

        if (mContext == null) {
            this.mContext = context;
        }
    }

    private Context getContext() {
        return mContext;
    }

    MediaPlayer getPlayerForFilename(String name, float volume, boolean shouldLoop) {
        if (player != null) {
            stopPlayer();
        }

        player = new MediaPlayer();
        player.setLooping(shouldLoop);
        player.setVolume(volume, volume);

//        https://stackoverflow.com/a/50882009/3670829
        if (Build.VERSION.SDK_INT >= 21) {
            player.setAudioAttributes(new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setLegacyStreamType(AudioManager.STREAM_ALARM)
                    .build());
        } else {
            player.setAudioStreamType(AudioManager.STREAM_ALARM);
        }

        try {
            String filename = "android.resource://" + mContext.getPackageName() + "/raw/" + name;
            player.setDataSource(mContext,Uri.parse(filename));
            player.prepare();
        } catch (IOException e) {
            e.printStackTrace();
        }

        return player;
    }

    void stopPlayer() {
        try {
            player.stop();
            player.reset();
            player.release();

            player = null;
        } catch (Exception e) {
            Log.e(TAG, "player not found");
        }
    }
}
