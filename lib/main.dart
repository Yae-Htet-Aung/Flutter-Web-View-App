import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

void main() {
  runApp(const WebViewApp());
}

class WebViewApp extends StatelessWidget {
  const WebViewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  final BlueThermalPrinter _printer = BlueThermalPrinter.instance;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'PrinterChannel',
        onMessageReceived: (JavaScriptMessage message) async {
          debugPrint("📩 Received message from webview");
          await _handlePrint(message.message);
        },
      )
      ..loadRequest(Uri.parse('https://admin.shweyokelayexpress.com/'));
  }

  Future<void> _handlePrint(String base64Str) async {
    debugPrint("🖨️ _handlePrint called");
    try {
      final connected = await _printer.isConnected;
      debugPrint("🔌 Printer connected? $connected");
      if (connected != true) {
        _showSnack("❌ Printer not connected");
        return;
      }

      Uint8List? bytes;
      try {
        bytes = base64Decode(base64Str);
        debugPrint("✅ Base64 decoded, ${bytes.length} bytes");
      } catch (e) {
        debugPrint("⚠️ Invalid base64 string: $e");
        _showSnack("Invalid print data");
        return;
      }

      await _printer.printImageBytes(bytes);
      await _printer.printNewLine();
      debugPrint("✅ Ticket printed successfully");
    } catch (e) {
      debugPrint("⚠️ Failed to print ticket: $e");
      _showSnack("Print failed: $e");
    }
  }

  Future<void> _selectPrinter() async {
    debugPrint("🖨️ _selectPrinter called");
    try {
      final devices = await _printer.getBondedDevices();
      debugPrint("📡 Found ${devices.length} bonded devices");

      if (devices.isEmpty) {
        _showSnack("No paired printers found");
        return;
      }

      final selected = await showDialog<BluetoothDevice>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Select Printer"),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final d = devices[index];
                  return ListTile(
                    title: Text(d.name ?? "Unknown"),
                    subtitle: Text(d.address ?? ""),
                    onTap: () {
                      debugPrint("📌 Selected printer: ${d.name}");
                      Navigator.pop(context, d);
                    },
                  );
                },
              ),
            ),
          );
        },
      );

      if (selected != null) {
        debugPrint("🔌 Connecting to printer ${selected.name}");
        await _printer.connect(selected);
        final connected = await _printer.isConnected;
        debugPrint("🔌 Connection status: $connected");
        _showSnack(
          connected == true
              ? "✅ Connected to ${selected.name}"
              : "❌ Failed to connect",
        );
      }
    } catch (e) {
      debugPrint("⚠️ Error selecting printer: $e");
      _showSnack("Printer error: $e");
    }
  }

  void _showSnack(String msg) {
    debugPrint("💬 Snack: $msg");
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false, // no back button
          title: null, // removed title
          actions: [
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: () {
                debugPrint("🖱️ Print icon pressed");
                _selectPrinter();
              },
            ),
          ],
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
