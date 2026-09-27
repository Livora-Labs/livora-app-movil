package com.grupolivoralabs.livora

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()

            // 1. Operaciones en Campo y Recolección (Urgent / Heads-up)
            val urgentChannel = NotificationChannel(
                "livora_collections_urgent",
                "Operaciones en Campo y Recolección",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alertas inmediatas sobre la llegada del recolector, cambios de ruta y PIN de validación."
                enableVibration(true)
                val soundUri = getSoundUri("alert_tone")
                if (soundUri != null) {
                    setSound(soundUri, audioAttributes)
                }
            }

            // 2. Billetera, Tokens y Canjes (High - Tokens LIVOs)
            val walletChannel = NotificationChannel(
                "livora_wallet_ledger",
                "Billetera, Tokens y Canjes",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Confirmación de transacciones en la red Stellar y acreditación de LIVOs."
                enableVibration(true)
                val soundUri = getSoundUri("transaction_tone")
                if (soundUri != null) {
                    setSound(soundUri, audioAttributes)
                }
            }

            // 3. Seguridad, Privacidad y Reclamos (High - Indecopi / Ley 29733)
            val legalChannel = NotificationChannel(
                "livora_legal_security",
                "Seguridad, Privacidad y Reclamos",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alertas de inicio de sesión, normativas de Indecopi y Ley N.° 29733."
                enableVibration(true)
            }

            // 4. Subastas y Asignaciones (Default)
            val auctionsChannel = NotificationChannel(
                "livora_auctions",
                "Subastas y Asignaciones",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Nuevas propuestas de Centros de Acopio y solicitudes disponibles."
                enableVibration(false)
            }

            // 5. Impacto Ambiental y Novedades (Low)
            val marketingChannel = NotificationChannel(
                "livora_engagement_marketing",
                "Impacto Ambiental y Novedades",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Resumen de reciclaje mensual, metas e impacto ambiental alcanzado."
                enableVibration(false)
            }

            notificationManager.createNotificationChannels(
                listOf(urgentChannel, walletChannel, legalChannel, auctionsChannel, marketingChannel)
            )
        }
    }

    private fun getSoundUri(soundName: String): Uri? {
        val resId = resources.getIdentifier(soundName, "raw", packageName)
        return if (resId != 0) {
            Uri.parse("android.resource://$packageName/$resId")
        } else {
            null // Fallback automático al sonido por defecto del sistema
        }
    }
}
