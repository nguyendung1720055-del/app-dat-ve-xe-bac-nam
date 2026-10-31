import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../api.dart';
import '../ui.dart';

class ScannerPage extends StatefulWidget {
  final Session session;
  final String? tripId;
  const ScannerPage({super.key, required this.session, this.tripId});
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with WidgetsBindingObserver {
  final controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.qrCode],
  );
  Json? result;
  String? raw, error;
  bool busy = false, stopped = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      controller.stop();
    } else if (state == AppLifecycleState.resumed && !stopped) {
      controller.start();
    }
  }

  Future<void> verify(String value, {bool board = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      raw = value;
      stopped = true;
      error = null;
    });
    await controller.stop();
    try {
      final response = Json.from(
        await widget.session.api.call(
          '/staff/verify',
          method: 'POST',
          data: {
            'qr': value,
            'board': board,
            if (widget.tripId != null) 'trip_id': widget.tripId,
          },
        ),
      );
      if (mounted) setState(() => result = response);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> paste() async {
    final text = await Clipboard.getData(Clipboard.kTextPlain);
    if (text?.text?.isNotEmpty == true) {
      await verify(text!.text!.trim());
    } else if (mounted) {
      toast(context, 'Chưa có nội dung QR trong bộ nhớ tạm.');
    }
  }

  void resume() {
    setState(() {
      stopped = false;
      result = null;
      error = null;
      raw = null;
    });
    controller.start();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kiểm tra QR lên xe')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Đặt QR vé vào giữa khung hình. ML Kit đọc mã trên Android; máy chủ giải mã và kiểm tra vé.',
            ),
            gap(),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: 300,
                child: MobileScanner(
                  controller: controller,
                  onDetect: (capture) {
                    for (final b in capture.barcodes) {
                      if (b.rawValue != null && !busy && !stopped) {
                        verify(b.rawValue!);
                        break;
                      }
                    }
                  },
                  errorBuilder: (context, error) => Container(
                    color: forest,
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Không mở được camera. Cấp quyền camera trong cài đặt hoặc thử trên điện thoại thật.',
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            gap(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => controller.toggleTorch(),
                    icon: const Icon(Icons.flash_on),
                    label: const Text('Đèn flash'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : paste,
                    icon: const Icon(Icons.paste),
                    label: const Text('Dán mã để thử'),
                  ),
                ),
              ],
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (error != null)
              panel(
                child: Column(
                  children: [
                    Text(error!),
                    TextButton(
                      onPressed: busy || raw == null
                          ? null
                          : () => verify(raw!),
                      child: const Text('Thử kiểm tra lại'),
                    ),
                  ],
                ),
              ),
            if (result != null)
              panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      result!['valid'] == true
                          ? Icons.verified_outlined
                          : Icons.cancel_outlined,
                      size: 52,
                      color: result!['valid'] == true ? forest : Colors.red,
                    ),
                    gap(),
                    Text(
                      result!['message'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    gap(),
                    if (result!['booking'] != null)
                      ticketSummary(Json.from(result!['booking'])),
                    if (result!['valid'] == true &&
                        result!['booking']?['status'] == 'paid')
                      FilledButton(
                        onPressed: busy
                            ? null
                            : () async {
                                if (await confirm(
                                  context,
                                  'Xác nhận khách lên xe?',
                                  'Vé sẽ được đánh dấu đã sử dụng và không thể dùng lần nữa.',
                                )) {
                                  await verify(raw!, board: true);
                                }
                              },
                        child: const Text('Xác nhận lên xe'),
                      ),
                  ],
                ),
              ),
            if (stopped)
              FilledButton.tonal(
                onPressed: busy ? null : resume,
                child: const Text('Quét vé tiếp theo'),
              ),
            gap(),
            const Text(
              'Mất kết nối không đồng nghĩa vé hợp lệ. Vé chưa thanh toán, QR bị sửa, sai chuyến hoặc đã sử dụng sẽ không được xác nhận.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    ),
  );
}
