package com.example.memory_trigger

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat

object NotificationHelper {

    /**
     * Показывает уведомление для слова.
     */
    fun showWordNotification(
        context: Context,
        wordId: Long,
        foreignWord: String,
        translation: String
    ) {
        val notifId     = DatabaseHelper.NOTIFICATION_ID
        val packageName = context.packageName

        val audioUrl = "https://translate.google.com/translate_tts" +
                "?ie=UTF-8&tl=en&client=tw-ob&q=${Uri.encode(foreignWord)}"

        val playPendingIntent = PendingIntent.getBroadcast(
            context, 1,
            Intent(context, PlayReceiver::class.java).apply {
                putExtra("audioUrl", audioUrl)
                putExtra("notificationId", notifId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val highPendingIntent = makePriorityIntent(context, wordId, DatabaseHelper.PRIORITY_HIGH, requestCode = 2)
        val mediumPendingIntent = makePriorityIntent(context, wordId, DatabaseHelper.PRIORITY_MEDIUM, requestCode = 3)
        val lowPendingIntent = makePriorityIntent(context, wordId, DatabaseHelper.PRIORITY_LOW, requestCode = 4)

        val dismissPendingIntent = PendingIntent.getBroadcast(
            context, 5,
            Intent(context, DismissReceiver::class.java).apply {
                putExtra("wordId", wordId)
                putExtra("title",  foreignWord)
                putExtra("body",   translation)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val emptyPendingIntent = PendingIntent.getBroadcast(
            context, 0, Intent(),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val collapsed = RemoteViews(packageName, R.layout.notification_collapsed).apply {
            setTextViewText(R.id.notification_word, foreignWord)
            setOnClickPendingIntent(R.id.btn_play,            playPendingIntent)
            setOnClickPendingIntent(R.id.btn_priority_high,   highPendingIntent)
            setOnClickPendingIntent(R.id.btn_priority_medium, mediumPendingIntent)
            setOnClickPendingIntent(R.id.btn_priority_low,    lowPendingIntent)
        }

        val expanded = RemoteViews(packageName, R.layout.notification_expanded).apply {
            setTextViewText(R.id.notification_word, foreignWord)
            setTextViewText(R.id.notification_body, translation)
            setOnClickPendingIntent(R.id.btn_play,            playPendingIntent)
            setOnClickPendingIntent(R.id.btn_priority_high,   highPendingIntent)
            setOnClickPendingIntent(R.id.btn_priority_medium, mediumPendingIntent)
            setOnClickPendingIntent(R.id.btn_priority_low,    lowPendingIntent)
        }

        val notification = NotificationCompat.Builder(context, MainActivity.CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setCustomContentView(collapsed)
            .setCustomBigContentView(expanded)
            .setOngoing(true)
            .setDeleteIntent(dismissPendingIntent)
            .setContentIntent(emptyPendingIntent)
            .setAutoCancel(false)
            .setDefaults(NotificationCompat.DEFAULT_SOUND)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .build()

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(notifId, notification)

        // Сохраняем ID последнего показанного слова
        DatabaseHelper.getInstance(context).setLastWordId(wordId)
        MainActivity.sendEvent("db_changed")
    }

    fun scheduleRepeatingNotification(context: Context, word: String, translation: String, wordId: Long) {
        val db = DatabaseHelper.getInstance(context)
        
        // Сразу помечаем слово как "следующее активное" в базе
        db.setLastWordId(wordId)
        MainActivity.sendEvent("db_changed")

        // Закрываем предыдущее уведомление, если оно было
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(DatabaseHelper.NOTIFICATION_ID)

        val delaySeconds = db.getDelaySeconds()

        if (delaySeconds <= 0) {
            showWordNotification(context, wordId, word, translation)
            return
        }

        val intent = Intent(context, NotificationReceiver::class.java).apply {
            putExtra("title",  word)
            putExtra("body",   translation)
            putExtra("wordId", wordId)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context, DatabaseHelper.NOTIFICATION_ID, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        val triggerTime  = System.currentTimeMillis() + delaySeconds * 1000L

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            if (alarmManager.canScheduleExactAlarms()) {
                alarmManager.setExactAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
            } else {
                alarmManager.set(android.app.AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
            }
        } else {
            alarmManager.setExactAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
        }
    }

    private fun makePriorityIntent(
        context: Context,
        wordId: Long,
        priority: Int,
        requestCode: Int
    ): PendingIntent {
        val intent = Intent(context, PriorityReceiver::class.java).apply {
            putExtra("wordId",   wordId)
            putExtra("priority", priority)
        }
        return PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
