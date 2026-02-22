package com.example.memory_trigger

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Обрабатывает смахивание (удаление) уведомления пользователем.
 * Если уведомление просто закрыто (не через кнопки действий),
 * мы планируем показ ЭТОГО ЖЕ слова заново через стандартную задержку.
 */
class DismissReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "DismissReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val wordId = intent.getLongExtra("wordId", -1L)
        val title  = intent.getStringExtra("title") ?: ""
        val body   = intent.getStringExtra("body") ?: ""

        if (wordId == -1L) {
            Log.d(TAG, "Dismissed notification without wordId, skipping reschedule")
            return
        }

        Log.d(TAG, "Notification dismissed by user. Rescheduling same word: id=$wordId ($title)")

        NotificationHelper.scheduleRepeatingNotification(context, title, body, wordId)
    }
}
