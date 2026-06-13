import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/support_provider.dart';
import '../../services/socket_service.dart';
import 'support_category_selection_screen.dart';
import 'support_ticket_chat_screen.dart';
import '../../widgets/support_category_badge.dart';

class SupportHubScreen extends StatefulWidget {
  const SupportHubScreen({super.key});

  @override
  State<SupportHubScreen> createState() => _SupportHubScreenState();
}

class _SupportHubScreenState extends State<SupportHubScreen> {
  Future<void> _openNewTicket() async {
    final nav = Navigator.of(context);
    final support = context.read<SupportProvider>();
    final created = await nav.push<SupportTicketModel?>(
      MaterialPageRoute(
        builder: (_) => const SupportCategorySelectionScreen(),
      ),
    );
    if (!mounted) return;
    await support.fetchTickets();
    if (created == null) return;
    if (!mounted) return;
    await nav.push(
      MaterialPageRoute(
        builder: (_) => SupportTicketChatScreen(
          ticketId: created.id,
          subject: created.subject,
          ticketNumber: created.ticketNumber,
          categoryCode: created.category,
          categoryDetail: created.categoryDetail,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await SocketService().connect();
      if (!mounted) return;
      await context.read<SupportProvider>().fetchTickets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Support'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<SupportProvider>().fetchTickets(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Consumer<SupportProvider>(
              builder: (context, support, _) {
                if (support.loadingTickets && support.tickets.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (support.ticketsError != null && support.tickets.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(support.ticketsError!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => support.fetchTickets(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Text(
                        'Your tickets',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (support.tickets.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                        child: Text(
                          'No tickets yet.\nUse the New ticket button below for live chat with our team.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      ...support.tickets.map((t) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              title: Text(
                                t.subject,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (t.category.isNotEmpty) ...[
                                    SupportCategoryBadge(
                                      categoryCode: t.category,
                                      categoryDetail: t.categoryDetail,
                                      compact: true,
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  Text(
                                '${t.ticketNumber} · ${t.status}'
                                '${t.needsRating ? ' · Awaiting feedback' : ''}'
                                    '${t.lastMessagePreview.isNotEmpty ? '\n${t.lastMessagePreview}' : ''}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              trailing: t.unreadByTransporter > 0
                                  ? Badge(
                                      label: Text('${t.unreadByTransporter}'),
                                      child: const Icon(Icons.chat_bubble_outline),
                                    )
                                  : const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SupportTicketChatScreen(
                                      ticketId: t.id,
                                      subject: t.subject,
                                      ticketNumber: t.ticketNumber,
                                      categoryCode: t.category,
                                      categoryDetail: t.categoryDetail,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    const Divider(height: 32),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Other ways to reach us',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.email_outlined),
                            title: const Text('Email'),
                            subtitle: const Text('support@porttivo.com'),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.phone_outlined),
                            title: const Text('Phone'),
                            subtitle: const Text('+91 1800-XXX-XXXX'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Material(
            elevation: 6,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _openNewTicket,
                    icon: const Icon(Icons.add_comment_outlined),
                    label: const Text('New ticket'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
