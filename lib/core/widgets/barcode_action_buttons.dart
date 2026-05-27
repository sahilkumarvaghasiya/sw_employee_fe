import 'package:flutter/material.dart';

class BarcodeActionButtons extends StatelessWidget {
  const BarcodeActionButtons({
    super.key,
    required this.isDownloading,
    required this.isPrinting,
    required this.onDownload,
    required this.onPrint,
    this.downloadLabel = 'Download',
    this.printLabel = 'Print Barcode',
  });

  final bool isDownloading;
  final bool isPrinting;
  final VoidCallback onDownload;
  final VoidCallback onPrint;
  final String downloadLabel;
  final String printLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isDownloading ? null : onDownload,
            icon: isDownloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            label: Text(isDownloading ? 'Downloading...' : downloadLabel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: isPrinting ? null : onPrint,
            icon: isPrinting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined),
            label: Text(isPrinting ? 'Printing...' : printLabel),
          ),
        ),
      ],
    );
  }
}
