import 'package:flutter/material.dart';

import '../../core/config/api_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/media_url.dart';
import '../../core/utils/user_feedback.dart';
import '../../data/models/kyc_model.dart';
import '../../services/kyc_service.dart';

class KycDocumentsScreen extends StatefulWidget {
  const KycDocumentsScreen({super.key});

  @override
  State<KycDocumentsScreen> createState() => _KycDocumentsScreenState();
}

class _KycDocItem {
  const _KycDocItem({
    required this.label,
    required this.url,
    this.maskedNumber,
  });

  final String label;
  final String url;
  final String? maskedNumber;

  bool get isPdf {
    final path = url.split('?').first.toLowerCase();
    return path.endsWith('.pdf');
  }
}

class _KycDocumentsScreenState extends State<KycDocumentsScreen> {
  final _kycService = KycService();
  bool _loading = true;
  String? _error;
  TransporterKyc? _kyc;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final kyc = await _kycService.getKyc();
      if (!mounted) return;
      setState(() {
        _kyc = kyc;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load KYC documents';
        _loading = false;
      });
      showUserErrorSnackBar(context, e, fallback: 'Could not load KYC documents');
    }
  }

  List<_KycDocItem> _docs(TransporterKyc kyc) {
    final items = <_KycDocItem>[];
    void add(String label, String? url, String? path, String? number) {
      final resolved = resolveUploadUrl(ApiConfig.baseUrl, url ?? path);
      if (resolved.isEmpty) return;
      final masked = maskKycNumber(number);
      items.add(
        _KycDocItem(
          label: label,
          url: resolved,
          maskedNumber: masked.isEmpty ? null : masked,
        ),
      );
    }

    add('PAN', kyc.panImage, kyc.panImagePath, kyc.panNumber);
    add('Aadhaar front', kyc.aadhaarImage, kyc.aadhaarImagePath, kyc.aadhaarNumber);
    add('Aadhaar back', kyc.aadhaarBackImage, kyc.aadhaarBackImagePath, null);
    return items;
  }

  void _openViewer(_KycDocItem doc) {
    if (doc.isPdf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open this PDF from a browser or file viewer.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _KycDocumentViewer(title: doc.label, url: doc.url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final kyc = _kyc;
    final docs = kyc == null ? const <_KycDocItem>[] : _docs(kyc);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('KYC documents')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: textTheme.bodyMedium),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: docs.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: [
                            const SizedBox(height: 80),
                            const Icon(Icons.folder_off_outlined, size: 56),
                            const SizedBox(height: 16),
                            Text(
                              'No KYC documents uploaded yet.',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 24),
                            if (kyc?.isCompleted != true)
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.of(context).pushNamed('/kyc'),
                                child: const Text('Complete KYC'),
                              ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            return ListTile(
                              tileColor: AppColors.offWhite,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              leading: Icon(
                                doc.isPdf
                                    ? Icons.picture_as_pdf_outlined
                                    : Icons.image_outlined,
                              ),
                              title: Text(doc.label),
                              subtitle: doc.maskedNumber == null
                                  ? null
                                  : Text(doc.maskedNumber!),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openViewer(doc),
                            );
                          },
                        ),
                ),
    );
  }
}

class _KycDocumentViewer extends StatelessWidget {
  const _KycDocumentViewer({required this.title, required this.url});

  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Could not load this document.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
