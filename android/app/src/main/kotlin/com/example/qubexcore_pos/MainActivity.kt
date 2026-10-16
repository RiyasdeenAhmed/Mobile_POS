package com.example.qubexcore_pos

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothSocket
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val bluetoothSpp = java.util.UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private var bluetoothPermissionResult: MethodChannel.Result? = null
    private var pending: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "qubex/retail_files").setMethodCallHandler { call, result ->
            try {
                if (pending != null) { result.error("busy", "Finish the open file picker first", null); return@setMethodCallHandler }
                when (call.method) {
                    "barcodeApp" -> {
                        val launch = packageManager.getLaunchIntentForPackage("com.xinye.barcode4")
                        startActivity(launch ?: Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=com.xinye.barcode4")))
                        result.success(null)
                    }
                    "folder" -> {
                        pending = result
                        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION), 101)
                    }
                    "csv" -> {
                        pending = result
                        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).setType("*/*").addCategory(Intent.CATEGORY_OPENABLE), 102)
                    }
                    "save" -> {
                        val bytes = call.argument<ByteArray>("bytes")!!
                        val name = call.argument<String>("name")!!
                        val mime = call.argument<String>("mime")!!
                        val folder = call.argument<String>("folder")
                        if (folder == null) {
                            pending = result; pendingBytes = bytes
                            startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).setType(mime).addCategory(Intent.CATEGORY_OPENABLE).putExtra(Intent.EXTRA_TITLE, name), 103)
                        } else {
                            val tree = Uri.parse(folder)
                            val parent = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
                            val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
                            val names = mutableSetOf<String>()
                            contentResolver.query(children, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)?.use { c -> while (c.moveToNext()) names.add(c.getString(0)) }
                            var unique = name; var n = 1
                            while (names.contains(unique)) {
                                val dot = name.lastIndexOf('.')
                                unique = if (dot > 0) "${name.substring(0, dot)} (${n++})${name.substring(dot)}" else "$name (${n++})"
                            }
                            val uri = DocumentsContract.createDocument(contentResolver, parent, mime, unique) ?: error("Could not create document")
                            try { write(uri, bytes) } catch (e: Exception) { DocumentsContract.deleteDocument(contentResolver, uri); throw e }
                            result.success(unique)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { pending = null; pendingBytes = null; result.error("file_access", "File access failed. Choose an accessible folder and try again.", null) }
        }
        MethodChannel(engine.dartExecutor.binaryMessenger, "qubexcore/bluetooth_printer").setMethodCallHandler { call, result ->
            handleBluetooth(call.method, call.arguments, result)
        }
    }

    private fun bluetoothPermissionGranted(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
        ActivityCompat.checkSelfPermission(this, android.Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    private fun handleBluetooth(method: String, arguments: Any?, result: MethodChannel.Result) {
        try {
            val adapter = BluetoothAdapter.getDefaultAdapter() ?: run {
                result.error("unsupported", "This device does not support Bluetooth", null); return
            }
            when (method) {
                "requestPermission" -> {
                    if (bluetoothPermissionGranted()) result.success(true)
                    else if (bluetoothPermissionResult != null) result.error("permission_pending", "A permission request is already open", null)
                    else {
                        bluetoothPermissionResult = result
                        requestPermissions(arrayOf(android.Manifest.permission.BLUETOOTH_CONNECT, android.Manifest.permission.BLUETOOTH_SCAN), 401)
                    }
                }
                "openPairingSettings" -> { startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS)); result.success(null) }
                "bluetoothStatus" -> result.success(mapOf("enabled" to (bluetoothPermissionGranted() && adapter.isEnabled), "permissionGranted" to bluetoothPermissionGranted()))
                "pairedDevices" -> {
                    if (!bluetoothPermissionGranted()) { result.error("permission_denied", "Nearby devices permission is required", null); return }
                    if (!adapter.isEnabled) { result.error("disabled", "Bluetooth is turned off", null); return }
                    result.success(adapter.bondedDevices.map { mapOf("name" to (it.name ?: "Bluetooth device"), "address" to it.address) })
                }
                "print" -> {
                    if (!bluetoothPermissionGranted()) { result.error("permission_denied", "Nearby devices permission is required", null); return }
                    if (!adapter.isEnabled) { result.error("disabled", "Bluetooth is turned off", null); return }
                    @Suppress("UNCHECKED_CAST")
                    val values = arguments as? Map<String, Any?>
                    val address = values?.get("address") as? String
                    val bytes = (values?.get("bytes") as? List<Int> ?: emptyList()).map { it.toByte() }.toByteArray()
                    if (address.isNullOrBlank() || bytes.isEmpty()) { result.error("invalid_job", "Printer address and receipt data are required", null); return }
                    Thread {
                        var socket: BluetoothSocket? = null
                        var completed = false
                        try {
                            socket = adapter.getRemoteDevice(address).createRfcommSocketToServiceRecord(bluetoothSpp)
                            adapter.cancelDiscovery(); socket.connect()
                            socket.outputStream.use { it.write(bytes); it.flush() }
                            // XP-365B can acknowledge the RFCOMM write before its
                            // print buffer has received the final bytes.
                            Thread.sleep(150)
                            completed = true
                        } catch (e: Exception) { runOnUiThread { result.error("print_failed", e.message ?: "Printer is disconnected", null) } }
                        finally {
                            try { socket?.close() } catch (_: Exception) {}
                            if (completed) runOnUiThread { result.success(null) }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) { result.error("bluetooth_error", e.message, null) }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 401) { bluetoothPermissionResult?.success(bluetoothPermissionGranted()); bluetoothPermissionResult = null }
    }
    private fun write(uri: Uri, bytes: ByteArray) {
        val stream = contentResolver.openOutputStream(uri, "w") ?: error("Destination unavailable")
        stream.use { it.write(bytes); it.flush() }
    }
    @Deprecated("Legacy activity result bridge")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode !in 101..103) return
        val result = pending ?: return
        val bytes = pendingBytes
        pending = null; pendingBytes = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { result.success(null); return }
        try {
            when (requestCode) {
                101 -> {
                    val flags = data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                    contentResolver.takePersistableUriPermission(uri, flags)
                    result.success(uri.toString())
                }
                102 -> {
                    val input = contentResolver.openInputStream(uri) ?: error("File unavailable")
                    val content = input.use { stream ->
                        val buffer = ByteArray(8192)
                        val output = java.io.ByteArrayOutputStream()
                        while (true) {
                            val count = stream.read(buffer)
                            if (count < 0) break
                            if (output.size() + count > 5 * 1024 * 1024) error("CSV exceeds 5 MB")
                            output.write(buffer, 0, count)
                        }
                        output.toByteArray()
                    }
                    if (content.size > 5 * 1024 * 1024) error("CSV exceeds 5 MB")
                    result.success(String(content, Charsets.UTF_8))
                }
                103 -> { write(uri, bytes ?: error("Missing export")); result.success(uri.toString()) }
            }
        } catch (e: Exception) { result.error("file_access", "Could not read or save the file. Check access and try again.", null) }
    }
}
