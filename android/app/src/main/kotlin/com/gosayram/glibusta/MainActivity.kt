package com.gosayram.glibusta

import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.gosayram.glibusta/storage_bridge"
    private var pendingResult: MethodChannel.Result? = null

    private val openTreeLauncher: ActivityResultLauncher<Uri?> =
        registerForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri: Uri? ->
            if (uri != null && pendingResult != null) {
                val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                try {
                    contentResolver.takePersistableUriPermission(uri, flags)
                    pendingResult!!.success(uri.toString())
                } catch (e: SecurityException) {
                    pendingResult!!.error("PERMISSION_ERROR", "Cannot persist URI permission: ${e.message}", null)
                }
                pendingResult = null
            } else {
                pendingResult?.success(null)
                pendingResult = null
            }
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handleMethodCall(call, result) }
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickFolder" -> {
                pendingResult = result
                openTreeLauncher.launch(null)
            }
            "scanBooks" -> {
                val folderUri = call.argument<String>("uri")
                if (folderUri == null) {
                    result.error("INVALID_ARG", "URI is required", null)
                    return
                }
                scanBooks(Uri.parse(folderUri), result)
            }
            "readFile" -> {
                val fileUri = call.argument<String>("uri")
                if (fileUri == null) {
                    result.error("INVALID_ARG", "URI is required", null)
                    return
                }
                readFile(Uri.parse(fileUri), result)
            }
            "getPersistedUris" -> {
                val uris = contentResolver.persistedUriPermissions
                    .map { it.uri.toString() }
                result.success(uris)
            }
            else -> result.notImplemented()
        }
    }

    private fun scanBooks(treeUri: Uri, result: MethodChannel.Result) {
        try {
            val root = DocumentFile.fromTreeUri(this, treeUri)
            if (root == null) {
                result.error("SCAN_ERROR", "Cannot access folder", null)
                return
            }

            val supportedExtensions = listOf("epub", "fb2", "zip", "txt", "rtf", "pdf", "mobi", "djvu", "djv")
            val books = mutableListOf<Map<String, Any>>()

            for (file in root.listFiles()) {
                if (!file.isFile) continue
                val name = file.name ?: continue
                val ext = name.substringAfterLast('.', "").lowercase()
                if (ext !in supportedExtensions) continue

                books.add(mapOf(
                    "uri" to file.uri.toString(),
                    "name" to name,
                    "size" to file.length(),
                    "extension" to ext,
                ))
            }

            result.success(books)
        } catch (e: Exception) {
            result.error("SCAN_ERROR", e.message, null)
        }
    }

    private fun readFile(fileUri: Uri, result: MethodChannel.Result) {
        try {
            contentResolver.openInputStream(fileUri)?.use { input ->
                val bytes = input.readBytes()
                result.success(bytes)
            } ?: result.error("READ_ERROR", "Cannot open file", null)
        } catch (e: Exception) {
            result.error("READ_ERROR", e.message, null)
        }
    }
}
