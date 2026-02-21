package com.example.memory_trigger

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.util.Log

class PlayReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "PlayReceiver"
        private var mediaPlayer: MediaPlayer? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        val audioUrl = intent.getStringExtra("audioUrl") ?: return

        Log.d(TAG, "Playing audio: $audioUrl")

        // Останавливаем предыдущее воспроизведение если есть
        mediaPlayer?.apply {
            if (isPlaying) stop()
            release()
        }
        mediaPlayer = null

        try {
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .build()
                )
                setDataSource(audioUrl)
                setOnPreparedListener { mp ->
                    mp.start()
                    Log.d(TAG, "Audio started")
                }
                setOnCompletionListener { mp ->
                    mp.release()
                    mediaPlayer = null
                    Log.d(TAG, "Audio completed")
                }
                setOnErrorListener { mp, what, extra ->
                    Log.e(TAG, "MediaPlayer error: what=$what, extra=$extra")
                    mp.release()
                    mediaPlayer = null
                    true
                }
                prepareAsync()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error playing audio: ${e.message}")
            mediaPlayer?.release()
            mediaPlayer = null
        }
    }
}
