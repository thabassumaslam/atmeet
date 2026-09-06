import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../controllers/meeting_controller.dart';
import '../domain/meeting.dart';
import '../services/window_actions.dart';

class MeetHome extends StatefulWidget {
  const MeetHome({
    super.key,
    required this.controller,
    required this.isDesktop,
  });
  final MeetingController controller;
  final bool isDesktop;

  @override
  State<MeetHome> createState() => _MeetHomeState();
}

class _MeetHomeState extends State<MeetHome> {
  final _composer = TextEditingController();
  final _scrollController = ScrollController();
  int _messageCount = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  void _changed() {
    if (!mounted) return;
    if (_messageCount != widget.controller.messages.length) {
      _messageCount = widget.controller.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ClipRRect(
          borderRadius: widget.isDesktop
              ? const BorderRadius.all(Radius.circular(28))
              : BorderRadius.zero,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AtMeetColors.black,
              border: widget.isDesktop
                  ? Border.all(color: Colors.white.withValues(alpha: 0.12))
                  : null,
            ),
            child: Column(
              children: [
                _Header(
                  isDesktop: widget.isDesktop,
                  controller: controller,
                  onLibrary: () => _showLibrary(context),
                  onSettings: () => _showSettings(context),
                ),
                if (controller.errorMessage != null)
                  _ErrorBanner(
                    message: controller.errorMessage!,
                    onClose: controller.clearError,
                  ),
                Expanded(
                  child: _Conversation(
                    controller: controller,
                    composer: _composer,
                    scrollController: _scrollController,
                  ),
                ),
                _DeviceDeck(controller: controller),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLibrary(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _LibraryDialog(controller: widget.controller),
    );
  }

  Future<void> _showSettings(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _SettingsDialog(controller: widget.controller),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.isDesktop,
    required this.controller,
    required this.onLibrary,
    required this.onSettings,
  });
  final bool isDesktop;
  final MeetingController controller;
  final VoidCallback onLibrary;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: isDesktop ? (_) => startDragging() : null,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              const SizedBox(width: 4),
              const Text(
                '@meet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8),
              if (controller.isRecording)
                const _StatusPill(label: 'REC', color: AtMeetColors.orange)
              else if (controller.isBusy)
                const _StatusPill(
                  label: 'LOCAL ASR',
                  color: AtMeetColors.electricBlue,
                )
              else
                const _StatusPill(label: 'PRIVATE', color: Color(0xFF47C978)),
              const Spacer(),
              _HeaderButton(
                tooltip: 'Recordings',
                icon: Icons.view_list_rounded,
                onTap: onLibrary,
              ),
              _HeaderButton(
                tooltip: 'Settings',
                icon: Icons.tune_rounded,
                onTap: onSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        color: Colors.white.withValues(alpha: 0.7),
      ),
    );
  }
}

class _Conversation extends StatelessWidget {
  const _Conversation({
    required this.controller,
    required this.composer,
    required this.scrollController,
  });
  final MeetingController controller;
  final TextEditingController composer;
  final ScrollController scrollController;

  void _send() {
    final text = composer.text;
    composer.clear();
    controller.ask(text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: controller.initialized
              ? ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(17, 8, 17, 12),
                  itemCount: controller.messages.length,
                  itemBuilder: (context, index) => _MessageBubble(
                    message: controller.messages[index],
                    key: ValueKey('${controller.messages[index].time}-$index'),
                  ),
                )
              : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 3, 15, 13),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF0E0F11),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 16,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: composer,
                    onSubmitted: (_) => _send(),
                    textInputAction: TextInputAction.send,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Ask about this meeting…',
                      hintStyle: TextStyle(color: AtMeetColors.muted),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.only(
                        left: 18,
                        right: 8,
                        bottom: 3,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Material(
                    color: AtMeetColors.electricBlue,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _send,
                      child: const SizedBox(
                        width: 38,
                        height: 38,
                        child: Icon(Icons.arrow_upward_rounded, size: 22),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({super.key, required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isPerson = message.role == ChatRole.person;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isPerson
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isPerson) ...[
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: _AssistantOrb(size: 31),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isPerson
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 285),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isPerson ? AtMeetColors.blue : AtMeetColors.bubble,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isPerson ? 18 : 7),
                      topRight: Radius.circular(isPerson ? 7 : 18),
                      bottomLeft: const Radius.circular(18),
                      bottomRight: const Radius.circular(18),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: isPerson
                          ? const Color(0xFF061423)
                          : const Color(0xFFF3F4F6),
                      height: 1.32,
                      fontSize: 13.5,
                      fontWeight: isPerson ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _clock(message.time),
                  style: const TextStyle(
                    color: Color(0xFF666A72),
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _clock(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    return '$hour:${time.minute.toString().padLeft(2, '0')} ${time.hour < 12 ? 'AM' : 'PM'}';
  }
}

class _AssistantOrb extends StatelessWidget {
  const _AssistantOrb({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 0.9,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFF2BE4FF),
            Color(0xFF006BFF),
            Color(0xFF2217D7),
          ],
          stops: [0, 0.16, 0.56, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF008CFF).withValues(alpha: 0.75),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }
}

class _DeviceDeck extends StatelessWidget {
  const _DeviceDeck({required this.controller});
  final MeetingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 225,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF0F0ED), Color(0xFFD2D2CE)],
        ),
        border: Border(top: BorderSide(color: Color(0xFF777773), width: 1.3)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 18, 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 145,
                    child: Stack(
                      children: [
                        const Positioned(
                          top: 0,
                          left: 0,
                          child: Text(
                            'TP–7',
                            style: TextStyle(
                              color: Color(0xFF5A5A58),
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ),
                        Align(
                          alignment: const Alignment(0.12, 0.62),
                          child: _Reel(
                            elapsed: controller.elapsed,
                            active: controller.isRecording,
                          ),
                        ),
                        Positioned(
                          right: 4,
                          bottom: 3,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF454544),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black45, blurRadius: 3),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _DigitalDisplay(controller: controller)),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 73,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFF777773), width: 1.2),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TransportButton(
                      tooltip: controller.isRecording
                          ? 'Already recording'
                          : 'Record',
                      onTap: controller.isBusy
                          ? null
                          : controller.startRecording,
                      child: Container(
                        width: 25,
                        height: 25,
                        decoration: BoxDecoration(
                          color: AtMeetColors.orange,
                          shape: BoxShape.circle,
                          boxShadow: controller.isRecording
                              ? const [
                                  BoxShadow(
                                    color: Color(0xAAFF3B16),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _TransportButton(
                      tooltip: controller.isRecording
                          ? 'Pause'
                          : controller.isPaused
                          ? 'Resume'
                          : controller.isPlaying
                          ? 'Pause playback'
                          : 'Play latest recording',
                      onTap: controller.isRecording || controller.isPaused
                          ? controller.togglePause
                          : controller.selectedMeeting?.audioPath != null
                          ? controller.togglePlayback
                          : null,
                      child: Icon(
                        controller.isPaused
                            ? Icons.play_arrow_rounded
                            : controller.isRecording || controller.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: const Color(0xFF454544),
                        size: 35,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _TransportButton(
                      tooltip: 'Stop and save',
                      onTap: controller.isRecording || controller.isPaused
                          ? controller.stopRecording
                          : controller.hasActivePlayback
                          ? controller.stopPlayback
                          : null,
                      child: Container(
                        width: 22,
                        height: 22,
                        color: const Color(0xFF454544),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.tooltip,
    required this.onTap,
    required this.child,
  });
  final String tooltip;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? 0.36 : 1,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Color(0xFF777773), width: 1.2),
                ),
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _Reel extends StatelessWidget {
  const _Reel({required this.elapsed, required this.active});
  final Duration elapsed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: active ? elapsed.inMilliseconds / 760 : 0,
      child: Container(
        width: 94,
        height: 94,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF535351), width: 1.2),
        ),
        child: Stack(
          children: [
            const Positioned(top: 11, left: 18, child: _ReelText('96/24')),
            const Positioned(
              right: 14,
              top: 15,
              child: SizedBox(
                width: 22,
                child: Divider(color: Color(0xFF535351), thickness: 1.2),
              ),
            ),
            const Positioned(
              right: 4,
              bottom: 23,
              child: RotatedBox(quarterTurns: 3, child: _ReelText('30M')),
            ),
            Center(
              child: Container(
                width: 43,
                height: 43,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment(-0.3, -0.35),
                    colors: [
                      Colors.white,
                      Color(0xFF9E9E9B),
                      Color(0xFFF0F0ED),
                      Color(0xFF777773),
                    ],
                    stops: [0, 0.3, 0.72, 1],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 3,
                      offset: Offset(1, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReelText extends StatelessWidget {
  const _ReelText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF5A5A58),
      fontSize: 11,
      letterSpacing: 1.4,
    ),
  );
}

class _DigitalDisplay extends StatelessWidget {
  const _DigitalDisplay({required this.controller});
  final MeetingController controller;

  @override
  Widget build(BuildContext context) {
    final elapsed = controller.elapsed;
    final hours = elapsed.inHours.toString().padLeft(2, '0');
    final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final now = DateTime.now();
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return Container(
      height: 101,
      padding: const EdgeInsets.fromLTRB(13, 10, 11, 9),
      decoration: BoxDecoration(
        color: const Color(0xFF080808),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                controller.isBusy
                    ? 'TRANSCRIBING'
                    : controller.isPaused
                    ? 'PAUSED'
                    : 'TODAY',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              if (controller.isRecording || controller.isPaused)
                _MiniWave(level: controller.amplitude)
              else
                const Text(
                  'LOCAL',
                  style: TextStyle(fontSize: 9, color: Color(0xFFBFC2C7)),
                ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$hours:$minutes:$seconds',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 29,
                fontWeight: FontWeight.w700,
                height: 0.95,
                letterSpacing: -2.1,
              ),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Text(
                  controller.selectedMeeting?.title.toUpperCase() ?? 'MEET 001',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, letterSpacing: 0.6),
                ),
              ),
              Text(
                '${months[now.month - 1]} ${now.day}, ${now.year}',
                style: const TextStyle(fontSize: 9, color: Color(0xFFD6D6D6)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniWave extends StatelessWidget {
  const _MiniWave({required this.level});
  final double level;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(7, (index) {
        final variance = 0.45 + math.sin(index * 1.7).abs() * 0.55;
        return Container(
          width: 2,
          height: 4 + level * 13 * variance,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: AtMeetColors.orange,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onClose});
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF351414),
      padding: const EdgeInsets.only(left: 14),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: Color(0xFFFF8173),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFFFFC3BC)),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 16),
          ),
        ],
      ),
    );
  }
}

class _LibraryDialog extends StatelessWidget {
  const _LibraryDialog({required this.controller});
  final MeetingController controller;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390, maxHeight: 590),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Recordings',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text(
                'Stored only on this device',
                style: TextStyle(color: AtMeetColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: controller.meetings.isEmpty
                    ? const Center(
                        child: Text(
                          'Your recordings will appear here.',
                          style: TextStyle(color: AtMeetColors.muted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: controller.meetings.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: Color(0xFF2A2C30)),
                        itemBuilder: (context, index) {
                          final meeting = controller.meetings[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: () {
                              controller.select(meeting);
                              Navigator.pop(context);
                            },
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AtMeetColors.orange.withValues(
                                  alpha: 0.12,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.graphic_eq_rounded,
                                color: AtMeetColors.orange,
                                size: 19,
                              ),
                            ),
                            title: Text(
                              meeting.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${_date(meeting.createdAt)} · ${_duration(meeting.durationMs)} · '
                              '${meeting.transcript.isEmpty ? 'Not transcribed' : 'Transcribed'}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AtMeetColors.muted,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: AtMeetColors.muted,
                            ),
                          );
                        },
                      ),
              ),
              if (controller.selectedMeeting?.audioPath != null &&
                  controller.selectedMeeting!.transcript.isEmpty &&
                  controller.modelReady)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: controller.isBusy
                        ? null
                        : () {
                            Navigator.pop(context);
                            controller.transcribeSelected();
                          },
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('Transcribe selected locally'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _date(DateTime value) =>
      '${value.day}/${value.month}/${value.year}';
  static String _duration(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog({required this.controller});
  final MeetingController controller;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'On-device models',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF202226),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                  child: Row(
                    children: [
                      const _AssistantOrb(size: 38),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Whisper Tiny English',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Fast offline transcription · ≈ 113 MB',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AtMeetColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        controller.modelReady
                            ? Icons.check_circle_rounded
                            : Icons.download_rounded,
                        color: controller.modelReady
                            ? const Color(0xFF47C978)
                            : AtMeetColors.blue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (controller.modelProgress > 0 && !controller.modelReady) ...[
                  LinearProgressIndicator(
                    value: controller.modelProgress,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Installing ${(controller.modelProgress * 100).round()}%',
                    style: const TextStyle(
                      color: AtMeetColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: controller.modelReady
                          ? null
                          : controller.downloadModel,
                      child: Text(
                        controller.modelReady
                            ? 'Installed'
                            : 'Download offline model',
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 17,
                      color: AtMeetColors.muted,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Audio, transcripts, and questions never leave this device. No account or API key is used.',
                        style: TextStyle(
                          color: AtMeetColors.muted,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
