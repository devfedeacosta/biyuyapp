package com.example.biyuyapp

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.biyuyapp/launcher"

    private fun isPackageInstalled(pkg: String): Boolean {
        // Method 1: try launching via intent (works on Android 13+)
        val launchIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
            setPackage(pkg)
        }
        val resolvedActivities: List<ResolveInfo> = packageManager.queryIntentActivities(launchIntent, 0)
        return resolvedActivities.isNotEmpty()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "launchApp" -> {
                        val pkg = call.argument<String>("package")!!
                        val activity = call.argument<String>("activity")
                        try {
                            val intent = if (activity != null) {
                                Intent(Intent.ACTION_MAIN).apply {
                                    addCategory(Intent.CATEGORY_LAUNCHER)
                                    component = ComponentName(pkg, activity)
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                            } else {
                                // Find launcher activity dynamically
                                val launchIntent = Intent(Intent.ACTION_MAIN).apply {
                                    addCategory(Intent.CATEGORY_LAUNCHER)
                                    setPackage(pkg)
                                }
                                val resolved = packageManager.queryIntentActivities(launchIntent, 0)
                                if (resolved.isNotEmpty()) {
                                    val info = resolved[0].activityInfo
                                    Intent(Intent.ACTION_MAIN).apply {
                                        addCategory(Intent.CATEGORY_LAUNCHER)
                                        component = ComponentName(info.packageName, info.name)
                                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                    }
                                } else {
                                    throw Exception("App not found: $pkg")
                                }
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("LAUNCH_FAILED", e.message, null)
                        }
                    }

                    "getInstalledApps" -> {
                        val packages = call.argument<List<String>>("packages")!!
                        val installed = packages.filter { isPackageInstalled(it) }
                        result.success(installed)
                    }

                    "isAppInstalled" -> {
                        val pkg = call.argument<String>("package")!!
                        result.success(isPackageInstalled(pkg))
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
