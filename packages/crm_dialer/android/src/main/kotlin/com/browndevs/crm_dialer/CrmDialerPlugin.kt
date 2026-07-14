package com.browndevs.crm_dialer

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telecom.TelecomManager
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

// We need to import CrmInCallService from the main app package if possible,
// OR we move CrmInCallService to this plugin too.
// Since CrmInCallService is in com.example.crmapp, we can access it if we add dependency or via reflection? 
// No, simpler is to EXPECT the app to have CrmInCallService or move it here.
// For now, let's assume we can access it by fully qualified name or just duplicate the callback mechanism cleanly.
// Actually, moving CrmInCallService to the plugin package is cleaner, but it modifies AndroidManifest.
// Let's use reflection or similar if we can't importing directly.
// Wait, the plugin is a library module. The Main App depends on it. The Plugin CANNOT depend on Main App classes.
// So `CrmInCallService` logic involving `updateCallback` needs to be handled carefully.
// Best approach: "Callbacks" object that CrmInCallService uses, defined in this Plugin or shared?
// Or we just move CrmInCallService to this Plugin package? Yes, that's better. But `InCallService` is a manifest entry.
// Let's stick to the MethodHandler logic first. 
// For `placeCall`, we just need Context.

class CrmDialerPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var channel : MethodChannel
  private lateinit var context : Context
  
  // Hardcoded channel name to match existing Dart code
  private val CHANNEL_NAME = "com.trevioncrm/dialer" 

  private lateinit var callStateReceiver: android.content.BroadcastReceiver

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
    
    // Register BroadcastReceiver for Native->Flutter events
    callStateReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
             if (intent.action == "com.trevioncrm.CALL_STATE") {
                  val type = intent.getStringExtra("type")
                  val number = intent.getStringExtra("number")
                  val data = intent.getStringExtra("data")
                  val phoneAccountId = intent.getStringExtra("phoneAccountId")
                  if (type != null) {
                      val args = mapOf("type" to type, "number" to number, "data" to data, "phoneAccountId" to phoneAccountId)
                      channel.invokeMethod("onCallStateChanged", args)
                  }
             }
        }
    }
    
    val filter = android.content.IntentFilter("com.trevioncrm.CALL_STATE")
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        context.registerReceiver(callStateReceiver, filter, Context.RECEIVER_EXPORTED)
    } else {
        context.registerReceiver(callStateReceiver, filter)
    }
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
        "placeCall" -> {
             val number = call.argument<String>("number")
             if (number != null) {
                 placeCall(number)
             }
             result.success(true)
        }
        "acceptCall" -> {
             sendControlBroadcast("ACCEPT")
             result.success(true)
        }
        "hangupCall" -> {
             sendControlBroadcast("HANGUP")
             result.success(true)
        }
        "setHold" -> {
             val hold = call.argument<Boolean>("hold") ?: false
             sendControlBroadcast("HOLD", hold)
             result.success(true)
        }
        "checkIsDefault" -> {
             checkIsDefault(result)
        }
        "requestRole" -> {
             requestRole()
             result.success(true)
        }
        "startOverlay" -> {
             val name = call.argument<String>("name") ?: "Unknown"
             val number = call.argument<String>("number") ?: ""
             val makeCall = call.argument<Boolean>("makeCall") ?: false
             val extraData = call.argument<Map<String, Any>>("extraData")
             startOverlay(name, number, makeCall, extraData)
             result.success(true)
        }
        "stopOverlay" -> {
             stopOverlay()
             result.success(true)
        }
        "getSimNumber" -> {
             val number = getSimNumber()
             result.success(number)
        }
        "getActiveSims" -> {
             val sims = getActiveSims()
             result.success(sims)
        }
        else -> {
             result.notImplemented()
        }
    }
  }

  private fun sendControlBroadcast(action: String, hold: Boolean? = null) {
      val intent = Intent("com.trevioncrm.ACTION_CALL_CONTROL")
      intent.putExtra("EXTRA_ACTION", action)
      if (hold != null) {
          intent.putExtra("EXTRA_HOLD", hold)
      }
      intent.setPackage(context.packageName)
      context.sendBroadcast(intent)
  }

  private fun placeCall(number: String) {
        val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
        val isDefault = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = context.getSystemService(Context.ROLE_SERVICE) as RoleManager
            roleManager.isRoleHeld(RoleManager.ROLE_DIALER)
        } else {
            telecomManager.defaultDialerPackage == context.packageName
        }

        if (isDefault) {
            val uri = android.net.Uri.fromParts("tel", number, null)
            val extras = android.os.Bundle()
            extras.putBoolean(TelecomManager.EXTRA_START_CALL_WITH_SPEAKERPHONE, false)
            try {
                if (context.checkSelfPermission(android.Manifest.permission.CALL_PHONE) == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                    telecomManager.placeCall(uri, extras)
                    return
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // Fallback or Non-Default Dialer
        val uri = "tel:" + number
        val intent = Intent(Intent.ACTION_CALL)
        intent.setData(android.net.Uri.parse(uri))
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        
        try {
             if (context.checkSelfPermission(android.Manifest.permission.CALL_PHONE) == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                context.startActivity(intent)
             } else {
                val dialIntent = Intent(Intent.ACTION_DIAL)
                dialIntent.setData(android.net.Uri.parse(uri))
                dialIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(dialIntent)
             }
        } catch (e: Exception) {
            e.printStackTrace()
        }
  }

  private fun getSimNumber(): String? {
       // Strategy 1: SubscriptionManager (Iterate all active SIMs)
       try {
           val subscriptionManager = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as android.telephony.SubscriptionManager
           val infoList = subscriptionManager.activeSubscriptionInfoList
           
           if (infoList != null) {
               android.util.Log.d("DialerPlugin", "getSimNumber: Found ${infoList.size} active subscriptions.")
               for (info in infoList) {
                   var number = ""
                   if (android.os.Build.VERSION.SDK_INT >= 33) {
                       try {
                           number = subscriptionManager.getPhoneNumber(info.subscriptionId)
                           android.util.Log.d("DialerPlugin", "getSimNumber(API33): SubId=${info.subscriptionId}, Number='$number'")
                       } catch (e: Exception) {
                           android.util.Log.e("DialerPlugin", "getSimNumber(API33): Failed: $e")
                       }
                   } 
                   
                   // Fallback for API < 33 OR if API 33 returned empty (sometimes happens)
                   if (number.isEmpty()) {
                       number = info.number ?: ""
                       android.util.Log.d("DialerPlugin", "getSimNumber(Legacy): SubId=${info.subscriptionId}, Number='$number'")
                   }

                   if (!number.isNullOrEmpty()) {
                       return number
                   }
               }
           }
       } catch (e: Exception) {
           android.util.Log.e("DialerPlugin", "getSimNumber: SubscriptionManager failed: $e")
       }

       // Strategy 2: TelephonyManager (Fallback for Default SIM)
       try {
            val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as android.telephony.TelephonyManager
            val line1Number = telephonyManager.line1Number
            android.util.Log.d("DialerPlugin", "getSimNumber: TelephonyManager.line1Number='$line1Number'")
            if (!line1Number.isNullOrEmpty()) {
                return line1Number
            }
       } catch(e: Exception) {
            android.util.Log.e("DialerPlugin", "getSimNumber: TelephonyManager failed: $e")
       }

       return null
  }

  private fun checkIsDefault(result: Result) {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = context.getSystemService(Context.ROLE_SERVICE) as RoleManager
            result.success(roleManager.isRoleHeld(RoleManager.ROLE_DIALER))
      } else {
            val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            result.success(telecomManager.defaultDialerPackage == context.packageName)
      }
  }

  private fun requestRole() {
       // Requesting role requires Activity Context usually (startActivityForResult).
       // Application context needs FLAG_ACTIVITY_NEW_TASK.
       if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = context.getSystemService(Context.ROLE_SERVICE) as RoleManager
            if (roleManager.isRoleAvailable(RoleManager.ROLE_DIALER)) {
                if (!roleManager.isRoleHeld(RoleManager.ROLE_DIALER)) {
                    val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_DIALER)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                }
            }
        } else {
             val intent = Intent(TelecomManager.ACTION_CHANGE_DEFAULT_DIALER)
             intent.putExtra(TelecomManager.EXTRA_CHANGE_DEFAULT_DIALER_PACKAGE_NAME, context.packageName)
             intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
             context.startActivity(intent)
        }
  }

   private fun startOverlay(name: String, number: String, makeCall: Boolean, extraData: Map<String, Any>?) {
        // Use ComponentName to start service in main app package
        val intent = Intent()
        intent.setClassName(context, "com.trevioncrm.CallOverlayService")
        intent.putExtra("name", name)
        intent.putExtra("number", number)
        intent.putExtra("make_call", makeCall)
        
        // Pass essential IDs for logging
        if (extraData != null) {
            intent.putExtra("callId", extraData["callId"] as? String)
            intent.putExtra("uniqueCallId", extraData["uniqueCallId"] as? String)
            intent.putExtra("leadId", extraData["leadId"] as? String)
            intent.putExtra("userId", extraData["userId"] as? String)
            intent.putExtra("companyId", extraData["companyId"] as? String)
            intent.putExtra("direction", extraData["direction"] as? String)
        }
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
   }

    private fun stopOverlay() {
         val intent = Intent()
         intent.setClassName(context, "com.trevioncrm.CallOverlayService")
         try {
              context.stopService(intent)
         } catch (e: Exception) {
              e.printStackTrace() 
         }
    }

  private fun getActiveSims(): List<Map<String, Any?>> {
      val simsList = mutableListOf<Map<String, Any?>>()
      try {
          val subscriptionManager = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as android.telephony.SubscriptionManager
          if (context.checkSelfPermission(android.Manifest.permission.READ_PHONE_STATE) == android.content.pm.PackageManager.PERMISSION_GRANTED) {
              val infoList = subscriptionManager.activeSubscriptionInfoList
              if (infoList != null) {
                  for (info in infoList) {
                      var number = ""
                      if (android.os.Build.VERSION.SDK_INT >= 33) {
                          try {
                              number = subscriptionManager.getPhoneNumber(info.subscriptionId)
                          } catch (e: Exception) {
                              android.util.Log.e("DialerPlugin", "getActiveSims(API33) number failed: $e")
                          }
                      }
                      if (number.isEmpty()) {
                          number = info.number ?: ""
                      }
                      
                      val simInfo = mapOf(
                          "number" to number,
                          "displayName" to (info.displayName?.toString() ?: ""),
                          "subscriptionId" to info.subscriptionId,
                          "slotIndex" to info.simSlotIndex,
                          @Suppress("DEPRECATION") "iccId" to (info.iccId ?: "")
                      )
                      simsList.add(simInfo)
                  }
              }
          }
      } catch (e: Exception) {
          android.util.Log.e("DialerPlugin", "getActiveSims failed: $e")
      }
      return simsList
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    context.unregisterReceiver(callStateReceiver)
  }
}
