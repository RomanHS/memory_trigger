package com.example.memory_trigger

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import android.util.Log

object NotificationHelper {
    private const val TAG = "NotificationHelper"

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

        val db = DatabaseHelper.getInstance(context)
        val word = db.getWordById(wordId)
        val currentPriority = word?.get("priority") as? Int ?: DatabaseHelper.PRIORITY_HIGH

        val collapsed = RemoteViews(packageName, R.layout.notification_collapsed).apply {
            setTextViewText(R.id.notification_word, foreignWord)
            setOnClickPendingIntent(R.id.btn_play,            playPendingIntent)
            setOnClickPendingIntent(R.id.btn_priority_high,   highPendingIntent)
            setOnClickPendingIntent(R.id.btn_priority_medium, mediumPendingIntent)
            setOnClickPendingIntent(R.id.btn_priority_low,    lowPendingIntent)

            setTextViewText(R.id.btn_priority_high,   if (currentPriority == DatabaseHelper.PRIORITY_HIGH)   "✓" else "")
            setTextViewText(R.id.btn_priority_medium, if (currentPriority == DatabaseHelper.PRIORITY_MEDIUM) "✓" else "")
            setTextViewText(R.id.btn_priority_low,    if (currentPriority == DatabaseHelper.PRIORITY_LOW)    "✓" else "")
        }

        val expanded = RemoteViews(packageName, R.layout.notification_expanded).apply {
            setTextViewText(R.id.notification_word, foreignWord)
            setTextViewText(R.id.notification_body, translation)
            setOnClickPendingIntent(R.id.btn_play,            playPendingIntent)
            setOnClickPendingIntent(R.id.btn_priority_high,   highPendingIntent)
            setOnClickPendingIntent(R.id.btn_priority_medium, mediumPendingIntent)
            setOnClickPendingIntent(R.id.btn_priority_low,    lowPendingIntent)

            setTextViewText(R.id.btn_priority_high,   if (currentPriority == DatabaseHelper.PRIORITY_HIGH)   "✓" else "")
            setTextViewText(R.id.btn_priority_medium, if (currentPriority == DatabaseHelper.PRIORITY_MEDIUM) "✓" else "")
            setTextViewText(R.id.btn_priority_low,    if (currentPriority == DatabaseHelper.PRIORITY_LOW)    "✓" else "")
            // Ссылки на словари
            val googleUrl = "https://translate.google.com/m?sl=en&tl=ru&text=${Uri.encode(foreignWord)}&op=translate"
            val cambridgeUrl = "https://dictionary.cambridge.org/dictionary/english/${Uri.encode(foreignWord)}"

            val googleIntent = PendingIntent.getActivity(
                context, 6, 
                Intent(Intent.ACTION_VIEW, Uri.parse(googleUrl)),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val cambridgeIntent = PendingIntent.getActivity(
                context, 7,
                Intent(Intent.ACTION_VIEW, Uri.parse(cambridgeUrl)),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            setOnClickPendingIntent(R.id.btn_google, googleIntent)
            setOnClickPendingIntent(R.id.btn_cambridge, cambridgeIntent)
        }

        val notification = NotificationCompat.Builder(context, MainActivity.CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setCustomContentView(collapsed)
            .setCustomBigContentView(expanded)
            .setOngoing(true)
            .setDeleteIntent(dismissPendingIntent)
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

        val delaySeconds = db.getDelaySeconds()

        // Если задержка 0, показываем сразу, минуя AlarmManager.
        // Мы вызываем cancel(), чтобы "сбросить" состояние развернутости уведомления,
        // иначе пользователь сразу увидит перевод следующего слова.
        if (delaySeconds <= 0) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(DatabaseHelper.NOTIFICATION_ID)
            
            showWordNotification(context, wordId, word, translation)
            return
        }

        // Если есть задержка, убираем текущее уведомление из шторки
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(DatabaseHelper.NOTIFICATION_ID)

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

    fun restoreCycle(context: Context) {
        val db = DatabaseHelper.getInstance(context)
        val lastWordId = db.getLastWordId()
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Проверяем, существует ли еще это слово в базе
        val currentWord = if (lastWordId != -1L) db.getWordById(lastWordId) else null

        if (currentWord != null) {
            // Слово существует. Если оно уже в шторке — не трогаем.
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                val isShowing = nm.activeNotifications.any { it.id == DatabaseHelper.NOTIFICATION_ID }
                if (isShowing) return
            }

            val title = currentWord["foreign_word"] as? String ?: ""
            val body  = currentWord["translation"]  as? String ?: ""
            Log.d(TAG, "Restoring notification for word: id=$lastWordId ($title)")
            scheduleRepeatingNotification(context, title, body, lastWordId)
        } else {
            // Слова не существует (удалено) или его не было.
            // Убираем старое уведомление, если оно висит
            nm.cancel(DatabaseHelper.NOTIFICATION_ID)

            // Пробуем запустить цикл со следующего доступного слова
            val nextWord = db.getNextWord(lastWordId) // Если lastWordId был -1 или удален, getNextWord вернет первое или следующее
            if (nextWord != null) {
                val title = nextWord["foreign_word"] as? String ?: ""
                val body  = nextWord["translation"]  as? String ?: ""
                val nextId = nextWord["id"] as Long
                Log.d(TAG, "Starting/Restarting cycle from word: id=$nextId")
                scheduleRepeatingNotification(context, title, body, nextId)
            } else {
                // В базе вообще нет слов
                db.setLastWordId(-1L)
                MainActivity.sendEvent("db_changed")
                Log.d(TAG, "No words in DB to schedule")
            }
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
