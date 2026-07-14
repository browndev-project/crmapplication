package com.trevioncrm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import android.net.Uri
import androidx.core.app.NotificationCompat

class CallOverlayService : Service() {

    private lateinit var windowManager: WindowManager
    private var overlayView: View? = null

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onCreate() {
        super.onCreate()
         // Create Notification Channel for Foreground Service
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "overlay_channel",
                "Call Overlay",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
        
        val notification: Notification = NotificationCompat.Builder(this, "overlay_channel")
            .setContentTitle("CRM Dialer Running")
            .setContentText("Displaying call details overlay")
            .setSmallIcon(R.mipmap.ic_launcher)
            .build()

        try {
            startForeground(1, notification)
        } catch (e: Exception) {
            android.util.Log.e("CallOverlay", "Failed to start foreground service (Android 14+ background restriction): " + e.message)
            stopSelf()
        }

        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    private var callId: String? = null
    private var uniqueCallId: String? = null
    private var leadId: String? = null
    private var userId: String? = null
    private var companyId: String? = null
    private var direction: String? = null
    private var startTimeMillis: Long = 0
    private var callStartTimeIso: String? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP_OVERLAY") {
            stopSelf()
            return START_NOT_STICKY
        }

        // Capture Logging Data
        callId = intent?.getStringExtra("callId")
        uniqueCallId = intent?.getStringExtra("uniqueCallId")
        leadId = intent?.getStringExtra("leadId")
        userId = intent?.getStringExtra("userId")
        companyId = intent?.getStringExtra("companyId")
        direction = intent?.getStringExtra("direction") ?: "WEB_INITIATED"
        
        startTimeMillis = System.currentTimeMillis()
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            callStartTimeIso = java.time.Instant.now().toString()
        }
        
        // Listen to Phone State Updates
        val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as android.telephony.TelephonyManager
        telephonyManager.listen(object : android.telephony.PhoneStateListener() {
            private var hasCallStarted = false

            override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                super.onCallStateChanged(state, phoneNumber)
                
                android.util.Log.d("CallOverlay", "PhoneState: $state, hasCallStarted: $hasCallStarted")
                
                if (state == android.telephony.TelephonyManager.CALL_STATE_OFFHOOK || 
                    state == android.telephony.TelephonyManager.CALL_STATE_RINGING) {
                    hasCallStarted = true
                }
                
                if (state == android.telephony.TelephonyManager.CALL_STATE_IDLE) {
                     if (hasCallStarted) {
                         // End Call Logic
                         val endTimeMillis = System.currentTimeMillis()
                         var durationSeconds = (endTimeMillis - startTimeMillis) / 1000
                         if (durationSeconds < 0) durationSeconds = 0
                         
                         var endTimeIso = ""
                         if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                             endTimeIso = java.time.Instant.now().toString()
                         }

                         // Send Native Log if we have data
                         if (callId != null && userId != null) {
                             sendNativeLog(phoneNumber, durationSeconds, endTimeIso)
                         } else {
                             android.util.Log.e("CallOverlay", "Missing Log Data (CallID/UserID), skipping native log.")
                             stopSelf()
                         }
                     } else {
                         android.util.Log.d("CallOverlay", "Ignored IDLE (Call hasn't started yet)")
                     }
                }
            }
        }, android.telephony.PhoneStateListener.LISTEN_CALL_STATE)

        val name = intent?.getStringExtra("name") ?: "Unknown"
        val number = intent?.getStringExtra("number") ?: ""
        val shouldMakeCall = intent?.getBooleanExtra("make_call", false) ?: false
        
        android.util.Log.d("CallOverlay", "Showing overlay for $name ($number). Auto-Call: $shouldMakeCall")

        showOverlay(name, number)
        
        if (shouldMakeCall && number.isNotEmpty()) {
             android.util.Log.d("CallOverlay", "Attempting to initiate call to $number")
             
             if (checkSelfPermission(android.Manifest.permission.CALL_PHONE) == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                 val telecomManager = getSystemService(Context.TELECOM_SERVICE) as android.telecom.TelecomManager
                 val isDefault = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                     val roleManager = getSystemService(android.app.role.RoleManager::class.java)
                     roleManager.isRoleHeld(android.app.role.RoleManager.ROLE_DIALER)
                 } else {
                     telecomManager.defaultDialerPackage == packageName
                 }

                 if (isDefault) {
                     try {
                        val uri = Uri.fromParts("tel", number, null)
                        val extras = android.os.Bundle()
                        extras.putBoolean(android.telecom.TelecomManager.EXTRA_START_CALL_WITH_SPEAKERPHONE, false)
                        
                        android.util.Log.d("CallOverlay", "Calling telecomManager.placeCall...")
                        telecomManager.placeCall(uri, extras)
                     } catch (e: Exception) {
                        android.util.Log.e("CallOverlay", "TelecomManager failed: $e. Fallback to Intent.")
                        launchCallIntent(number)
                     }
                 } else {
                     android.util.Log.d("CallOverlay", "Not default dialer, using Intent fallback.")
                     launchCallIntent(number)
                 }
             } else {
                 android.util.Log.e("CallOverlay", "CALL_PHONE permission NOT granted in Service!")
             }
        }

        return START_NOT_STICKY
    }

    class CallLogInfo(val duration: Int, val phoneAccountId: String?)
    class SimCardInfo(val slot: String, val displayName: String, val number: String?)

    private fun getCallInfoFromSystem(context: Context, number: String?): CallLogInfo {
        if (number == null || number.isEmpty()) return CallLogInfo(0, null)
        var duration = 0
        var phoneAccountId: String? = null
        try {
            // Wait 2.5 seconds for system to write to call log
            Thread.sleep(2500)
            
            val cleanNumber = number.replace(Regex("\\D"), "")
            if (cleanNumber.isEmpty()) return CallLogInfo(0, null)
            
            val oneMinuteAgo = System.currentTimeMillis() - 60000
            val cursor = context.contentResolver.query(
                android.provider.CallLog.Calls.CONTENT_URI,
                arrayOf(
                    android.provider.CallLog.Calls.DURATION,
                    android.provider.CallLog.Calls.PHONE_ACCOUNT_ID
                ),
                "${android.provider.CallLog.Calls.NUMBER} LIKE ? AND ${android.provider.CallLog.Calls.DATE} >= ?",
                arrayOf("%$cleanNumber", oneMinuteAgo.toString()),
                "${android.provider.CallLog.Calls.DATE} DESC LIMIT 1"
            )
            cursor?.use {
                if (it.moveToFirst()) {
                    duration = it.getInt(it.getColumnIndexOrThrow(android.provider.CallLog.Calls.DURATION))
                    phoneAccountId = it.getString(it.getColumnIndexOrThrow(android.provider.CallLog.Calls.PHONE_ACCOUNT_ID))
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("CallOverlay", "Failed to query call log info: ${e.message}")
        }
        return CallLogInfo(duration, phoneAccountId)
    }

    private fun getSimDetails(context: Context, phoneAccountId: String?): SimCardInfo {
        var simSlot = "1"
        var simDisplayName = ""
        var simNumber: String? = null
        if (phoneAccountId == null || phoneAccountId.isEmpty()) {
            return SimCardInfo(simSlot, simDisplayName, simNumber)
        }
        try {
            if (context.checkSelfPermission(android.Manifest.permission.READ_PHONE_STATE) == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                val subscriptionManager = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? android.telephony.SubscriptionManager
                if (subscriptionManager != null) {
                    val activeList = subscriptionManager.activeSubscriptionInfoList
                    if (activeList != null) {
                        for (info in activeList) {
                            val subId = info.subscriptionId.toString()
                            val slotIndex = info.simSlotIndex.toString()
                            val iccId = @Suppress("DEPRECATION") (info.iccId ?: "")
                            
                            val matches = (phoneAccountId == subId) ||
                                          (phoneAccountId == slotIndex) ||
                                          (iccId.isNotEmpty() && (phoneAccountId == iccId || phoneAccountId.contains(iccId) || iccId.contains(phoneAccountId))) ||
                                          (phoneAccountId.endsWith("/$subId")) ||
                                          (phoneAccountId.endsWith("_$subId")) ||
                                          (phoneAccountId.contains("sub$subId"))
                                          
                            if (matches) {
                                simSlot = (info.simSlotIndex + 1).toString()
                                simDisplayName = info.displayName?.toString() ?: ""
                                
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                    try {
                                        simNumber = subscriptionManager.getPhoneNumber(info.subscriptionId)
                                    } catch (e: Exception) {}
                                }
                                if (simNumber.isNullOrEmpty()) {
                                    simNumber = info.number ?: ""
                                }
                                break
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("CallOverlay", "Failed to resolve SIM details: ${e.message}")
        }
        return SimCardInfo(simSlot, simDisplayName, simNumber)
    }

    private fun sendNativeLog(number: String?, duration: Long, endTime: String) {
        val finalNumber = number ?: "Unknown"
        
        // Native Thread for Network Request
        Thread {
            try {
                val context = applicationContext
                val callLogInfo = getCallInfoFromSystem(context, finalNumber)
                val actualDuration = callLogInfo.duration
                
                // Get SIM details
                val simInfo = getSimDetails(context, callLogInfo.phoneAccountId)
                
                val finalSlot = simInfo.slot
                val finalDispName = simInfo.displayName
                val finalSimNumber = simInfo.number
                
                // Construct callerNumber
                var callerNumber = ""
                if (!finalSimNumber.isNullOrEmpty()) {
                    callerNumber = if (finalDispName.isNotEmpty()) {
                        "$finalSimNumber ($finalDispName)"
                    } else {
                        finalSimNumber
                    }
                }
                
                val url = java.net.URL("https://crm-app-backend-btpi.onrender.com/api/v1/push/dialer/webhook")
                val conn = url.openConnection() as java.net.HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/json")
                conn.doOutput = true
                
                val uniqueId = uniqueCallId ?: "call_native_${System.currentTimeMillis()}"
                
                // Construct JSON (Manual String Building for 0 dependencies)
                // duration is total elapsed time (dialing + talk)
                val totalDuration = if (actualDuration > duration) actualDuration.toLong() else duration
                
                val callDetailsJson = if (actualDuration > 0) {
                    val dialingDur = if (totalDuration > actualDuration) totalDuration - actualDuration else 0L
                    var activeStartIso = callStartTimeIso
                    try {
                        val startInstant = java.time.Instant.parse(callStartTimeIso)
                        activeStartIso = startInstant.plusSeconds(dialingDur).toString()
                    } catch (e: Exception) {
                        // fallback to start time
                    }
                    "[{" +
                       "\"state\": \"DIALING\"," +
                       "\"startTime\": \"$callStartTimeIso\"," +
                       "\"endTime\": \"$activeStartIso\"," +
                       "\"duration\": $dialingDur" +
                    "},{" +
                       "\"state\": \"ACTIVE\"," +
                       "\"startTime\": \"$activeStartIso\"," +
                       "\"endTime\": \"$endTime\"," +
                       "\"duration\": $actualDuration" +
                    "},{" +
                       "\"state\": \"DISCONNECTED\"," +
                       "\"startTime\": \"$endTime\"," +
                       "\"endTime\": \"$endTime\"," +
                       "\"duration\": 0" +
                    "}]"
                } else {
                    "[{" +
                       "\"state\": \"DIALING\"," +
                       "\"startTime\": \"$callStartTimeIso\"," +
                       "\"endTime\": \"$endTime\"," +
                       "\"duration\": $totalDuration" +
                    "},{" +
                       "\"state\": \"DISCONNECTED\"," +
                       "\"startTime\": \"$endTime\"," +
                       "\"endTime\": \"$endTime\"," +
                       "\"duration\": 0" +
                    "}]"
                }

                val json = "{" +
                        "\"uniqueCallId\": \"$uniqueId\"," +
                        "\"callId\": \"$callId\"," +
                        "\"leadId\": \"$leadId\"," +
                        "\"userId\": \"$userId\"," +
                        "\"companyId\": \"$companyId\"," +
                        "\"receiverNumber\": \"$finalNumber\"," +
                        "\"callerNumber\": \"$callerNumber\"," +
                        "\"callType\": \"OUTGOING\"," +
                        "\"direction\": \"$direction\"," +
                        "\"startTime\": \"$callStartTimeIso\"," +
                        "\"endTime\": \"$endTime\"," +
                        "\"duration\": $totalDuration," +
                        "\"simSlot\": \"$finalSlot\"," +
                        "\"simDisplayName\": \"$finalDispName\"," +
                        "\"callDetails\": $callDetailsJson" +
                        "}"
                
                android.util.Log.d("CallOverlay", "Sending Native Log: $json")
                
                conn.outputStream.use { os ->
                    val input = json.toByteArray(java.nio.charset.StandardCharsets.UTF_8)
                    os.write(input, 0, input.size)
                }
                
                val responseCode = conn.responseCode
                android.util.Log.d("CallOverlay", "Log Sent. Response Code: $responseCode")
                
                if (responseCode in 200..299) {
                    // Success, delete the session file to prevent duplicate sends by Flutter
                    try {
                        var file = java.io.File(java.io.File(context.filesDir.parentFile, "app_flutter"), "active_call_session.json")
                        if (!file.exists()) {
                            file = java.io.File(context.filesDir, "active_call_session.json")
                        }
                        if (file.exists()) {
                            val diskContent = file.readText(java.nio.charset.StandardCharsets.UTF_8)
                            if (diskContent.isNotEmpty()) {
                                val diskJson = org.json.JSONObject(diskContent)
                                val diskUniqueId = diskJson.optString("uniqueCallId")
                                if (diskUniqueId == uniqueId) {
                                    if (file.delete()) {
                                        android.util.Log.d("CallOverlay", "Deleted session file successfully in overlay for $uniqueId.")
                                    } else {
                                        android.util.Log.e("CallOverlay", "Failed to delete session file in overlay.")
                                    }
                                } else {
                                    android.util.Log.d("CallOverlay", "Session file on disk belongs to another active session ($diskUniqueId). Keeping it.")
                                }
                            }
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("CallOverlay", "Error deleting session file: ${e.message}")
                    }
                }
                
            } catch (e: Exception) {
                android.util.Log.e("CallOverlay", "Failed to send native log: $e")
            } finally {
                // Ensure service is stopped after network call
                stopSelf()
            }
        }.start()
    }

    private fun launchCallIntent(number: String) {
        try {
            val uri = Uri.fromParts("tel", number, null)
            val callIntent = Intent(Intent.ACTION_CALL, uri)
            callIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(callIntent)
            android.util.Log.d("CallOverlay", "Fallback Intent launched.")
        } catch (e: Exception) {
            android.util.Log.e("CallOverlay", "Fallback Intent failed: $e")
            e.printStackTrace()
        }
    }

    private fun showOverlay(name: String, number: String) {
        try {
            if (overlayView != null) {
                try { windowManager.removeView(overlayView) } catch (e: Exception) {}
                overlayView = null
            }

            val context = this
            val dm = resources.displayMetrics

            // --- Root container fills full width so WindowManager can measure it ---
            val rootLayout = android.widget.LinearLayout(context)
            rootLayout.orientation = android.widget.LinearLayout.VERTICAL
            val rootPadding = (12 * dm.density).toInt()
            rootLayout.setPadding(rootPadding, rootPadding, rootPadding, rootPadding)

            // --- Card (horizontal row: text | call btn | open btn) ---
            val cardView = android.widget.LinearLayout(context)
            cardView.orientation = android.widget.LinearLayout.HORIZONTAL
            cardView.gravity = Gravity.CENTER_VERTICAL
            val cardPadding = (14 * dm.density).toInt()
            cardView.setPadding(cardPadding, cardPadding, cardPadding, cardPadding)

            val cardBg = android.graphics.drawable.GradientDrawable()
            cardBg.setColor(android.graphics.Color.WHITE)
            cardBg.cornerRadius = 24f * dm.density
            // Elevation-like shadow via stroke
            cardBg.setStroke((1 * dm.density).toInt(), android.graphics.Color.parseColor("#E0E0E0"))
            cardView.background = cardBg

            val cardParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
            )
            cardView.layoutParams = cardParams

            // --- Text block (name + number) weight=1 ---
            val textLayout = android.widget.LinearLayout(context)
            textLayout.orientation = android.widget.LinearLayout.VERTICAL
            val textParams = android.widget.LinearLayout.LayoutParams(
                0,
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT,
                1.0f
            )
            textLayout.layoutParams = textParams

            val nameView = TextView(context)
            nameView.text = if (name == "Unknown" || name.isBlank()) "Outgoing Call" else name
            nameView.textSize = 15f
            nameView.setTextColor(android.graphics.Color.parseColor("#111111"))
            nameView.setTypeface(null, android.graphics.Typeface.BOLD)
            nameView.maxLines = 1
            textLayout.addView(nameView)

            val numberView = TextView(context)
            numberView.text = number
            numberView.textSize = 12f
            numberView.setTextColor(android.graphics.Color.parseColor("#555555"))
            numberView.maxLines = 1
            textLayout.addView(numberView)

            cardView.addView(textLayout)

            // Gap between text and buttons
            val gap = (8 * dm.density).toInt()

            // --- Green "Call" button ---
            val btnCall = TextView(context)
            btnCall.text = "📞 Call"
            btnCall.textSize = 13f
            btnCall.setTextColor(android.graphics.Color.WHITE)
            btnCall.gravity = Gravity.CENTER
            btnCall.typeface = android.graphics.Typeface.DEFAULT_BOLD
            val bpH = (14 * dm.density).toInt()
            val bpV = (10 * dm.density).toInt()
            btnCall.setPadding(bpH, bpV, bpH, bpV)
            val callBg = android.graphics.drawable.GradientDrawable()
            callBg.setColor(android.graphics.Color.parseColor("#27C16B"))
            callBg.cornerRadius = 100f * dm.density
            btnCall.background = callBg
            val btnCallParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT,
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
            )
            btnCallParams.setMargins(gap, 0, gap, 0)
            btnCall.layoutParams = btnCallParams
            btnCall.setOnClickListener {
                try { launchCallIntent(number) } catch (e: Exception) { e.printStackTrace() }
            }
            cardView.addView(btnCall)

            // --- Dark "Open App" button ---
            val btnOpen = TextView(context)
            btnOpen.text = "App"
            btnOpen.textSize = 12f
            btnOpen.setTextColor(android.graphics.Color.WHITE)
            btnOpen.gravity = Gravity.CENTER
            btnOpen.typeface = android.graphics.Typeface.DEFAULT_BOLD
            btnOpen.setPadding(bpH, bpV, bpH, bpV)
            val openBg = android.graphics.drawable.GradientDrawable()
            openBg.setColor(android.graphics.Color.parseColor("#333333"))
            openBg.cornerRadius = 100f * dm.density
            btnOpen.background = openBg
            btnOpen.setOnClickListener {
                try {
                    stopSelf()
                    val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                    launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    if (launchIntent != null) startActivity(launchIntent)
                } catch (e: Exception) { e.printStackTrace() }
            }
            cardView.addView(btnOpen)

            rootLayout.addView(cardView)
            overlayView = rootLayout

            // WindowManager params — MATCH_PARENT width is essential for WRAP_CONTENT height to measure
            val layoutParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                else
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
                PixelFormat.TRANSLUCENT
            )
            layoutParams.gravity = Gravity.TOP
            layoutParams.y = 80

            windowManager.addView(overlayView, layoutParams)
            android.util.Log.d("CallOverlay", "Overlay added successfully with MATCH_PARENT width")
        } catch (e: Exception) {
            android.util.Log.e("CallOverlay", "showOverlay failed: ${e.message}")
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
             stopForeground(true)
        }
        
        if (overlayView != null) {
            try {
                windowManager.removeView(overlayView)
            } catch (e: Exception) {
                // View might already be gone
            }
            overlayView = null
        }
    }
}
