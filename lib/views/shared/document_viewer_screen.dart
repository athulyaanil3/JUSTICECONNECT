import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

class FullScreenDocumentViewer extends StatelessWidget {
  final String url;
  final bool isPdf;
  final String? title;

  const FullScreenDocumentViewer({
    super.key,
    required this.url,
    required this.isPdf,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title ?? (isPdf ? 'PDF Document Viewer' : 'Image Document Viewer'),
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Colors.white),
            tooltip: 'Open in Browser',
            onPressed: () async {
              try {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open external viewer')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error opening file: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: isPdf
          ? SfPdfViewer.network(
              url,
              canShowScrollHead: true,
              canShowScrollStatus: true,
              onDocumentLoadFailed: (details) {
                debugPrint('PDF load failed: ${details.description}');
              },
            )
          : Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: Colors.white,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 54),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load document.\nPlease ensure Supabase storage permissions allow access.',
                              style: GoogleFonts.inter(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final uri = Uri.parse(url);
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              },
                              icon: const Icon(Icons.open_in_browser),
                              label: const Text('Try Opening in Browser'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
