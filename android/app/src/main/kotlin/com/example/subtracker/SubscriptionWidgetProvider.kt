package com.example.subtracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class SubscriptionWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val serviceName = widgetData.getString("service_name", "No upcoming bills")
            val dueInfo = widgetData.getString("due_info", "Add subscriptions in app")
            val totalMonthly = widgetData.getString("total_monthly", "₹0")

            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val views = RemoteViews(context.packageName, R.layout.subscription_widget).apply {
                setTextViewText(R.id.widget_service_title, serviceName)
                setTextViewText(R.id.widget_due_details, dueInfo)
                setTextViewText(R.id.widget_total_spend, "Monthly: $totalMonthly")
                setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
