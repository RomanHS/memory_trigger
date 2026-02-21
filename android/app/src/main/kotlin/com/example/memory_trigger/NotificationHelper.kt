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
     * Использует фиксированный NOTIFICATION_ID = 1001, поэтому в системе
     * всегда не более одного уведомления от приложения.
     */
    fun showWordNotification(
        context: Context,
        wordId: Long,
        foreignWord: String,
        translation: String
    ) {
        val notifId     = DatabaseHelper.NOTIFICATION_ID
        val packageName = context.packageName

        // TTS URL строится из слова
        val audioUrl = "https://translate.google.com/translate_tts" +
                "?ie=UTF-8&tl=en&client=tw-ob&q=${Uri.encode(foreignWord)}"

        // ── PendingIntent: Play (request code = 1) ─────────────────────────
        val playPendingIntent = PendingIntent.getBroadcast(
            context, 1,
            Intent(context, PlayReceiver::class.java).apply {
                putExtra("audioUrl", audioUrl)
                putExtra("notificationId", notifId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ── PendingIntent: Высокий (priority=1, request code = 2) ─────────
        val highPendingIntent = makePriorityIntent(
            context, wordId, DatabaseHelper.PRIORITY_HIGH, requestCode = 2
        )

        // ── PendingIntent: Средний (priority=2, request code = 3) ─────────
        val mediumPendingIntent = makePriorityIntent(
            context, wordId, DatabaseHelper.PRIORITY_MEDIUM, requestCode = 3
        )

        // ── PendingIntent: Низкий (priority=3, request code = 4) ──────────
        val lowPendingIntent = makePriorityIntent(
            context, wordId, DatabaseHelper.PRIORITY_LOW, requestCode = 4
        )

        // ── PendingIntent: Dismiss (Request code = 5) ─────────────────────
        val dismissPendingIntent = PendingIntent.getBroadcast(
            context, 5,
            Intent(context, DismissReceiver::class.java).apply {
                putExtra("wordId", wordId)
                putExtra("title",  foreignWord)
                putExtra("body",   translation)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ── Tap on notification — не открывает приложение (request code = 0)
        val emptyPendingIntent = PendingIntent.getBroadcast(
            context, 0, Intent(),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ── Свёрнутый layout ──────────────────────────────────────────────
        val collapsed = RemoteViews(packageName, R.layout.notification_collapsed).apply {
            setTextViewText(R.id.notification_word, foreignWord)
            setOnClickPendingIntent(R.id.btn_play,            playPendingIntent)
            setOnClickPendingIntent(R.id.btn_priority_high,   highPendingIntent)
            setOnClickPendingIntent(R.id.btn_priority_medium, mediumPendingIntent)
            setOnClickPendingIntent(R.id.btn_priority_low,    lowPendingIntent)
        }

        // ── Развёрнутый layout ────────────────────────────────────────────
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
            .setOngoing(true) // Возвращаем запрет на смахивание
            .setDeleteIntent(dismissPendingIntent) // Оставляем на случай, если система всё же закроет
            .setContentIntent(emptyPendingIntent)
            .setAutoCancel(false)
            .setDefaults(NotificationCompat.DEFAULT_SOUND)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .build()

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(notifId, notification)
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
