import 'dart:convert';
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
          try {
            final base64Str = message.message;
            final bytes = base64Decode(base64Str);

            final connected = await _printer.isConnected;
            if (connected == true) {
              _printer.printImageBytes(bytes);
              _printer.printNewLine();
              _printer.paperCut();
              debugPrint("✅ Ticket printed successfully");
            } else {
              debugPrint("❌ Printer not connected");
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Printer not connected")),
                );
              }
            }
          } catch (e) {
            debugPrint("⚠️ Failed to print ticket: $e");
          }
        },
      )
      ..loadRequest(Uri.parse('https://shweyokelayexpress.com/'));
  }

  Future<void> _selectPrinter() async {
    try {
      final devices = await _printer.getBondedDevices();
      if (devices.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No paired printers found")),
          );
        }
        return;
      }

      // Show dialog with list of paired printers
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
                    onTap: () => Navigator.pop(context, d),
                  );
                },
              ),
            ),
          );
        },
      );

      if (selected != null) {
        await _printer.connect(selected);
        final connected = await _printer.isConnected;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                connected == true
                    ? "✅ Connected to ${selected.name}"
                    : "❌ Failed to connect",
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("⚠️ Error selecting printer: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("Ticket Printer"),
          actions: [
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: _selectPrinter, // open printer picker
            ),
          ],
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
