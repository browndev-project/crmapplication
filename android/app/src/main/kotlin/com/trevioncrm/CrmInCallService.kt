package com.trevioncrm

import android.content.Intent
import android.net.Uri
import android.telecom.Call
import android.telecom.InCallService
import android.util.Log
import android.content.Context
import android.os.Build
import android.telephony.SubscriptionManager
import org.json.JSONObject
import org.json.JSONArray
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets

class CrmInCallService : InCallService() {

    // Listener to track call state changes
    private val callback = object : Call.Callback() {
        override fun onStateChanged(call: Call, state: Int) {
            super.onStateChanged(call, state)
            Log.d(TAG, "onStateChanged: ${getStateString(state)}")
            if (state == Call.STATE_ACTIVE && connectTime == 0L) {
                connectTime = System.currentTimeMillis()
                Log.d(TAG, "Call went ACTIVE, connectTime recorded: $connectTime")
            }
            broadcastState(call)
        }

        override fun onDetailsChanged(call: Call, details: Call.Details) {
            super.onDetailsChanged(call, details)
            Log.d(TAG, "onDetailsChanged: $details")
            broadcastState(call)
        }
    }

    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        Log.d(TAG, "onCallAdded")

        currentCall = call
        callStartTime = System.currentTimeMillis()
        connectTime = if (call.state == Call.STATE_ACTIVE) System.currentTimeMillis() else 0L
        call.registerCallback(callback)
        broadcastState(call)

        // Launch UI
        // NOTE: This will only work if your app is the Default Dialer or has "Display over other apps" permission on Android 10+.
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("is_incoming_call", true)
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start activity: ${e.message}")
        }
    }

    override fun onCallRemoved(call: Call) {
        super.onCallRemoved(call)
        Log.d(TAG, "onCallRemoved")

        call.unregisterCallback(callback)

        if (currentCall == call) {
            currentCall = null
        }

        // TRIGGER NATIVE BACKGROUND CALL LOG SEND
        sendCallLogIfNeeded(call)
        connectTime = 0L
        callStartTime = 0L

        // Broadcast for plugins
        try {
            val intent = Intent("com.trevioncrm.CALL_STATE")
            intent.putExtra("type", "DISCONNECTED")
            intent.setPackage(packageName)
            sendBroadcast(intent)
        } catch(e: Exception) {}

        // FORCE LAUNCH APP via PendingIntent (Bypass BG restrictions)
        try {
            val launchIntent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("call_ended", true)
            }
            
            // On Android 10+, allowed if we have "Display over other apps" OR use FullScreenIntent
            // Since we are InCallService, we might not have permission to start activity directly if not default dialer UI.
            // But we can try PendingIntent.
            val pendingIntent = android.app.PendingIntent.getActivity(
                this, 0, launchIntent, 
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            
            // We can only use setFullScreenIntent with a Notification.
            // But just firing pendingIntent.send() might work if we have permission.
            pendingIntent.send()
            
            // Also try direct start for older Android
            startActivity(launchIntent)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch app on disconnect: ${e.message}")
        }
    }

    private fun getCallDurationFromSystem(context: Context, number: String): Int {
        var duration = 0
        try {
            // Wait 2 seconds for system to write to call log
            Thread.sleep(2000)
            
            val cleanNumber = number.replace(Regex("\\D"), "")
            if (cleanNumber.isEmpty()) return 0
            
            val oneMinuteAgo = System.currentTimeMillis() - 60000
            val cursor = context.contentResolver.query(
                android.provider.CallLog.Calls.CONTENT_URI,
                arrayOf(android.provider.CallLog.Calls.DURATION),
                "${android.provider.CallLog.Calls.NUMBER} LIKE ? AND ${android.provider.CallLog.Calls.DATE} >= ?",
                arrayOf("%$cleanNumber", oneMinuteAgo.toString()),
                "${android.provider.CallLog.Calls.DATE} DESC LIMIT 1"
            )
            cursor?.use {
                if (it.moveToFirst()) {
                    duration = it.getInt(it.getColumnIndexOrThrow(android.provider.CallLog.Calls.DURATION))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query call log duration: ${e.message}")
        }
        return duration
    }

    class SimCardInfo(val slot: String, val displayName: String, val number: String?)

    private fun getSimDetails(context: Context, phoneAccountId: String?): SimCardInfo {
        var simSlot = "1"
        var simDisplayName = ""
        var simNumber: String? = null
        if (phoneAccountId == null || phoneAccountId.isEmpty()) {
            return SimCardInfo(simSlot, simDisplayName, simNumber)
        }
        try {
            if (context.checkSelfPermission(android.Manifest.permission.READ_PHONE_STATE) == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                val subscriptionManager = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
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
            Log.e(TAG, "Failed to resolve SIM details: ${e.message}")
        }
        return SimCardInfo(simSlot, simDisplayName, simNumber)
    }

    private fun sendCallLogIfNeeded(endedCall: Call) {
        val context = applicationContext
        val handle: Uri? = endedCall.details?.handle
        val number = if (handle != null) Uri.decode(handle.schemeSpecificPart) else ""
        
        var phoneAccountId: String? = null
        try {
            val accountHandle = endedCall.details?.accountHandle
            if (accountHandle != null) {
                phoneAccountId = accountHandle.id
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get accountHandle: ${e.message}")
        }

        val disconnectTime = System.currentTimeMillis()
        var localDuration = 0
        if (callStartTime > 0L) {
            localDuration = ((disconnectTime - callStartTime) / 1000).toInt()
        } else if (connectTime > 0L) {
            localDuration = ((disconnectTime - connectTime) / 1000).toInt()
        }
        Log.d(TAG, "Call disconnected. Local duration: $localDuration seconds")

        Thread {
            try {
                // Find session file in app_flutter or files folder
                var file = File(File(context.filesDir.parentFile, "app_flutter"), "active_call_session.json")
                if (!file.exists()) {
                    file = File(context.filesDir, "active_call_session.json")
                }
                
                // Add a small retry mechanism if file is not written yet
                var retries = 3
                while (!file.exists() && retries > 0) {
                    Thread.sleep(500)
                    retries--
                }
                
                if (!file.exists()) {
                    Log.d(TAG, "No pending session file found in background.")
                    return@Thread
                }
                
                val content = file.readText(StandardCharsets.UTF_8)
                if (content.isEmpty()) return@Thread
                
                val sessionJson = JSONObject(content)
                val receiverNumber = sessionJson.optString("receiverNumber", "")
                
                // Soft warning instead of hard exit on mismatch
                val clean1 = number.replace(Regex("\\D"), "")
                val clean2 = receiverNumber.replace(Regex("\\D"), "")
                if (clean1.isNotEmpty() && clean2.isNotEmpty() && !clean1.endsWith(clean2) && !clean2.endsWith(clean1)) {
                    Log.w(TAG, "Session number mismatch: $receiverNumber vs $number. Proceeding anyway.")
                }
                
                Log.d(TAG, "Background sending log for session: ${sessionJson.optString("uniqueCallId")}")
                
                // 1. Resolve final duration and talk time
                val talkTime = getCallDurationFromSystem(context, number)
                
                val startTimeMillis = sessionJson.optLong("startTimeMillis", 0L)
                var elapsedDuration = 0
                if (startTimeMillis > 0L) {
                    elapsedDuration = ((System.currentTimeMillis() - startTimeMillis) / 1000).toInt()
                } else {
                    val startTimeStr = sessionJson.optString("startTime")
                    if (startTimeStr.isNotEmpty()) {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                val startInstant = java.time.Instant.parse(startTimeStr)
                                val endInstant = java.time.Instant.now()
                                elapsedDuration = java.time.Duration.between(startInstant, endInstant).seconds.toInt()
                            }
                        } catch (e: Exception) {}
                    }
                }
                if (elapsedDuration <= 0) {
                    elapsedDuration = localDuration
                }
                
                val totalDuration = if (talkTime > elapsedDuration) talkTime else elapsedDuration
                
                // 2. Get SIM slot details - preserve if already SIM 2
                val existingSlot = sessionJson.optString("simSlot", "")
                val simInfo = getSimDetails(context, phoneAccountId)
                val resolvedSlot = simInfo.slot
                val resolvedDispName = simInfo.displayName
                val resolvedSimNumber = simInfo.number
                
                val finalSlot = if (existingSlot == "2") "2" else resolvedSlot
                val finalDispName = if (existingSlot == "2") sessionJson.optString("simDisplayName", resolvedDispName) else resolvedDispName
                
                // 3. Update JSON values
                sessionJson.put("duration", totalDuration)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    sessionJson.put("endTime", java.time.Instant.now().toString())
                }
                sessionJson.put("simSlot", finalSlot)
                if (finalDispName.isNotEmpty()) {
                    sessionJson.put("simDisplayName", finalDispName)
                }
                
                // Update callerNumber with the correct SIM number and display name
                if (!resolvedSimNumber.isNullOrEmpty()) {
                    val formattedCaller = if (finalDispName.isNotEmpty()) {
                        "$resolvedSimNumber ($finalDispName)"
                    } else {
                        resolvedSimNumber
                    }
                    sessionJson.put("callerNumber", formattedCaller)
                } else {
                    // Fallback: update only display name if existing callerNumber does not have it
                    val currentCaller = sessionJson.optString("callerNumber", "")
                    if (finalDispName.isNotEmpty() && !currentCaller.contains(finalDispName)) {
                        if (currentCaller.contains("(")) {
                            sessionJson.put("callerNumber", currentCaller)
                        } else {
                            sessionJson.put("callerNumber", "$currentCaller ($finalDispName)")
                        }
                    }
                }
                
                // 4. Reconstruct clean call details array
                val finalDetails = JSONArray()
                
                if (talkTime > 0) {
                    val dialingDur = if (totalDuration > talkTime) totalDuration - talkTime else 0
                    val startTimeStr = sessionJson.optString("startTime")
                    val endTimeStr = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) java.time.Instant.now().toString() else startTimeStr
                    var activeStartIso = startTimeStr
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val startInstant = java.time.Instant.parse(startTimeStr)
                            activeStartIso = startInstant.plusSeconds(dialingDur.toLong()).toString()
                        }
                    } catch (e: Exception) {
                        // fallback
                    }

                    val dialingDetail = JSONObject()
                    dialingDetail.put("state", "DIALING")
                    dialingDetail.put("startTime", startTimeStr)
                    dialingDetail.put("endTime", activeStartIso)
                    dialingDetail.put("duration", dialingDur)
                    finalDetails.put(dialingDetail)
                    
                    val activeDetail = JSONObject()
                    activeDetail.put("state", "ACTIVE")
                    activeDetail.put("startTime", activeStartIso)
                    activeDetail.put("endTime", endTimeStr)
                    activeDetail.put("duration", talkTime)
                    finalDetails.put(activeDetail)
                } else {
                    val startTimeStr = sessionJson.optString("startTime")
                    val endTimeStr = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) java.time.Instant.now().toString() else startTimeStr
                    val dialingDetail = JSONObject()
                    dialingDetail.put("state", "DIALING")
                    dialingDetail.put("startTime", startTimeStr)
                    dialingDetail.put("endTime", endTimeStr)
                    dialingDetail.put("duration", totalDuration)
                    finalDetails.put(dialingDetail)
                }
                
                val discDetail = JSONObject()
                discDetail.put("state", "DISCONNECTED")
                val discTimeStr = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) java.time.Instant.now().toString() else sessionJson.optString("startTime")
                discDetail.put("startTime", discTimeStr)
                discDetail.put("endTime", discTimeStr)
                discDetail.put("duration", 0)
                finalDetails.put(discDetail)
                
                sessionJson.put("callDetails", finalDetails)
                sessionJson.remove("saved_details")
                
                // 5. Send Webhook
                val url = URL("https://crm-app-backend-btpi.onrender.com/api/v1/push/dialer/webhook")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/json")
                conn.doOutput = true
                conn.connectTimeout = 15000
                conn.readTimeout = 15000
                
                val jsonStr = sessionJson.toString()
                Log.d(TAG, "Background sending payload: $jsonStr")
                
                conn.outputStream.use { os ->
                    val input = jsonStr.toByteArray(StandardCharsets.UTF_8)
                    os.write(input, 0, input.size)
                }
                
                val responseCode = conn.responseCode
                Log.d(TAG, "Background Log Sent. Response Code: $responseCode")
                
                if (responseCode in 200..299) {
                    // Success, delete the session file safely only if it still belongs to this call session
                    try {
                        if (file.exists()) {
                            val diskContent = file.readText(StandardCharsets.UTF_8)
                            if (diskContent.isNotEmpty()) {
                                val diskJson = JSONObject(diskContent)
                                val diskUniqueId = diskJson.optString("uniqueCallId")
                                val sessionUniqueId = sessionJson.optString("uniqueCallId")
                                if (diskUniqueId == sessionUniqueId) {
                                    if (file.delete()) {
                                        Log.d(TAG, "Deleted session file successfully for $sessionUniqueId.")
                                    } else {
                                        Log.e(TAG, "Failed to delete session file.")
                                    }
                                } else {
                                    Log.d(TAG, "Session file on disk belongs to another active session ($diskUniqueId). Keeping it.")
                                }
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error performing safe session file deletion: ${e.message}")
                    }
                } else {
                    Log.e(TAG, "Webhook returned error status: $responseCode")
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send background call log: ${e.message}", e)
            }
        }.start()
    }


    private fun broadcastState(call: Call) {
        val stateStr = getStateString(call.state)

        var number = "Unknown"

        // Safe extraction of the phone number
        val handle: Uri? = call.details?.handle
        if (handle != null) {
            // schemeSpecificPart gets the number, Uri.decode removes URL encoding (like %2B for +)
            number = Uri.decode(handle.schemeSpecificPart)
        }

        var phoneAccountId: String? = null
        try {
            val accountHandle = call.details?.accountHandle
            if (accountHandle != null) {
                phoneAccountId = accountHandle.id
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get accountHandle: ${e.message}")
        }

        Log.d(TAG, "Broadcast: $stateStr for $number, phoneAccountId: $phoneAccountId")

        // Passing data: State|Number
        val data = "$stateStr|$number"

        // ALSO Send Standard Broadcast for Background Isolates / Plugins
        try {
            val intent = Intent("com.trevioncrm.CALL_STATE")
            intent.putExtra("type", stateStr)
            intent.putExtra("number", number)
            intent.putExtra("data", data)
            intent.putExtra("phoneAccountId", phoneAccountId)
            intent.setPackage(packageName) // Restrict to own app
            sendBroadcast(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send broadcast: ${e.message}")
        }
    }

    override fun onCreate() {
        super.onCreate()
        val filter = android.content.IntentFilter(ACTION_CALL_CONTROL)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(controlReceiver, filter, android.content.Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(controlReceiver, filter)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(controlReceiver)
        } catch (e: Exception) {}
    }

    private val controlReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: android.content.Context, intent: Intent) {
            if (intent.action == ACTION_CALL_CONTROL) {
                val action = intent.getStringExtra("EXTRA_ACTION")
                Log.d(TAG, "Control Action Received: $action")
                when (action) {
                    "ACCEPT" -> currentCall?.answer(0)
                    "HANGUP" -> currentCall?.disconnect()
                    "HOLD" -> {
                        val hold = intent.getBooleanExtra("EXTRA_HOLD", false)
                        if (hold) currentCall?.hold() else currentCall?.unhold()
                    }
                }
            }
        }
    }

    companion object {
        private const val TAG = "CrmInCallService"
        const val ACTION_CALL_CONTROL = "com.trevioncrm.ACTION_CALL_CONTROL"

        // Static reference to the current call (Be careful of memory leaks here in complex apps)
        var currentCall: Call? = null

        // Track connection time locally
        var connectTime: Long = 0L
        var callStartTime: Long = 0L

        fun getStateString(state: Int): String {
            return when (state) {
                Call.STATE_NEW -> "NEW"
                Call.STATE_RINGING -> "RINGING"
                Call.STATE_DIALING -> "DIALING"
                Call.STATE_ACTIVE -> "ACTIVE"
                Call.STATE_HOLDING -> "HOLDING"
                Call.STATE_DISCONNECTED -> "DISCONNECTED"
                Call.STATE_CONNECTING -> "CONNECTING"
                Call.STATE_DISCONNECTING -> "DISCONNECTING"
                Call.STATE_SELECT_PHONE_ACCOUNT -> "SELECT_PHONE_ACCOUNT"
                else -> "UNKNOWN_$state"
            }
        }
    }
}