package com.example.memory_trigger

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Обрабатывает события завершения загрузки устройства (BOOT_COMPLETED)
 * и обновления приложения (MY_PACKAGE_REPLACED).
 * Служит для восстановления цикла уведомлений, если он был прерван.
 */
class RestorationReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "RestorationReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d(TAG, "RestorationReceiver triggered with action: ${action}")

        if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            NotificationHelper.restoreCycle(context)
        }
    }
}
