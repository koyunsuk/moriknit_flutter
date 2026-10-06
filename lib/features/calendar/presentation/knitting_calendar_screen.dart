import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../data/calendar_event_aggregator.dart';
import '../data/knitting_event_repository.dart';
import '../domain/knitting_event.dart';

// 수동 추가 가능한 이벤트 타입 (자동생성 제외)
const _manualTypes = [
  KnittingEventType.needlePurchase,
  KnittingEventType.yarnPurchase,
  KnittingEventType.patternPurchase,
  KnittingEventType.toolPurchase,
  KnittingEventType.swatchComplete,
  KnittingEventType.memo,
];

// 이벤트 타입별 색상
Color _eventColor(KnittingEventType type) {
  switch (type) {
    case KnittingEventType.needlePurchase:
    case KnittingEventType.yarnPurchase:
    case KnittingEventType.patternPurchase:
    case KnittingEventType.toolPurchase:
      return C.og;
    case KnittingEventType.swatchComplete:
      return C.pk;
    case KnittingEventType.projectStart:
      return C.lv;
    case KnittingEventType.projectComplete:
      return C.lvD;
    case KnittingEventType.knitAlongStart:
      return C.pkD;
    case KnittingEventType.memo:
      return C.tx.withValues(alpha: 0.5);
  }
}

class KnittingCalendarScreen extends ConsumerStatefulWidget {
  const KnittingCalendarScreen({super.key});

  @override
  ConsumerState<KnittingCalendarScreen> createState() =>
      _KnittingCalendarScreenState();
}

class _KnittingCalendarScreenState
    extends ConsumerState<KnittingCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
  }

  List<KnittingEvent> _eventsForDay(
    DateTime day,
    Map<DateTime, List<KnittingEvent>> map,
  ) {
    final key = DateTime(day.year, day.month, day.day);
    return map[key] ?? [];
  }

  void _showAddSheet() {
    final language = ref.read(appLanguageProvider);
    final isKorean = language.isKorean;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEventSheet(
        initialDate: _selectedDay ?? DateTime.now(),
        isKorean: isKorean,
        onSave: (event) async {
          try {
            await runWithMoriLoadingDialog<void>(
              context,
              message: isKorean ? '저장하는 중입니다.' : 'Saving...',
              subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
              task: () async {
                await ref
                    .read(knittingEventRepositoryProvider)
                    .save(event);
              },
            );
            if (!mounted) return;
            showSavedSnackBar(
              ScaffoldMessenger.of(context),
              message: isKorean ? '저장됐어요.' : 'Saved.',
            );
          } catch (e) {
            if (!mounted) return;
            showSaveErrorSnackBar(
              ScaffoldMessenger.of(context),
              message: '$e',
            );
          }
        },
      ),
    );
  }

  Future<void> _deleteEvent(KnittingEvent event) async {
    final language = ref.read(appLanguageProvider);
    final isKorean = language.isKorean;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          isKorean ? '이벤트 삭제' : 'Delete Event',
          style: T.h3,
        ),
        content: Text(
          isKorean
              ? '"${event.title}" 이벤트를 삭제할까요?'
              : 'Delete "${event.title}"?',
          style: T.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isKorean ? '취소' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: C.og,
              foregroundColor: Colors.white,
            ),
            child: Text(isKorean ? '삭제' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    try {
      await runWithMoriLoadingDialog<void>(
        context,
        message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
        subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait a moment.',
        task: () async {
          await ref
              .read(knittingEventRepositoryProvider)
              .delete(event.id);
        },
      );
      if (!mounted) return;
      showSavedSnackBar(
        ScaffoldMessenger.of(context),
        message: isKorean ? '삭제됐어요.' : 'Deleted.',
      );
    } catch (e) {
      if (!mounted) return;
      showSaveErrorSnackBar(
        ScaffoldMessenger.of(context),
        message: '$e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(appLanguageProvider);
    final isKorean = language.isKorean;
    final eventsAsync = ref.watch(
      calendarEventsProvider((_focusedDay.year, _focusedDay.month)),
    );
    final eventsMap = eventsAsync.valueOrNull ?? {};
    final selectedEvents = _selectedDay != null
        ? _eventsForDay(_selectedDay!, eventsMap)
        : <KnittingEvent>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: Column(
              children: [
                MoriPageHeaderShell(
                  child: MoriWideHeader(
                    title: isKorean ? '뜨개 캘린더' : 'Knitting Calendar',
                    subtitle: isKorean ? '나의 뜨개 일정' : 'My Knitting Schedule',
                    trailing: [
                      IconButton(
                        icon: Icon(Icons.sync_rounded, color: C.tx),
                        tooltip:
                            isKorean ? '캘린더 연동 설정' : 'Calendar Sync',
                        onPressed: () =>
                            context.push(Routes.calendarSyncSettings),
                      ),
                    ],
                  ),
                ),
                // 캘린더 블록
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: MoriBlockShell(
                    label: isKorean ? '월간 뜨개 일정' : 'Monthly Schedule',
                    icon: Icons.calendar_month_rounded,
                    accent: C.lv,
                    bodyPadding: EdgeInsets.zero,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: TableCalendar<KnittingEvent>(
                      firstDay: DateTime(2020, 1, 1),
                      lastDay: DateTime(2030, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: CalendarFormat.month,
                      locale: isKorean ? 'ko_KR' : 'en_US',
                      eventLoader: (day) => _eventsForDay(day, eventsMap),
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      onDaySelected: (selected, focused) {
                        setState(() {
                          _selectedDay = selected;
                          _focusedDay = focused;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        setState(() {
                          _focusedDay = focusedDay;
                          _selectedDay = null;
                        });
                      },
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: C.lv.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: C.lv,
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: BoxDecoration(
                          color: C.og,
                          shape: BoxShape.circle,
                        ),
                        markersMaxCount: 3,
                        markerSize: 5,
                        markerMargin: const EdgeInsets.symmetric(horizontal: 0.5),
                        outsideDaysVisible: false,
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, day, events) {
                          if (events.isEmpty) return null;
                          // 이벤트 타입별 컬러 점 표시 (최대 3개)
                          final shown = events.take(3).toList();
                          return Positioned(
                            bottom: 2,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: shown
                                  .map(
                                    (e) => Container(
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 0.5),
                                      decoration: BoxDecoration(
                                        color: _eventColor(e.type),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          );
                        },
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                      ),
                    ),
                  ),
                ),
                ),
                const SizedBox(height: 12),
                // 선택된 날짜 이벤트 리스트
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: MoriBlockShell(
                      label: _selectedDay != null
                          ? (isKorean
                              ? '${_selectedDay!.month}월 ${_selectedDay!.day}일 일정'
                              : '${_selectedDay!.month}/${_selectedDay!.day} Events')
                          : (isKorean ? '날짜를 선택하세요' : 'Select a date'),
                      icon: Icons.list_rounded,
                      accent: C.pk,
                      child: selectedEvents.isEmpty
                          ? _EmptyEventPlaceholder(isKorean: isKorean)
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: selectedEvents.length,
                              separatorBuilder: (_, i) =>
                                  const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final event = selectedEvents[i];
                                return _EventListTile(
                                  event: event,
                                  isKorean: isKorean,
                                  onLongPress: event.isAutoGenerated
                                      ? null
                                      : () => _deleteEvent(event),
                                );
                              },
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSheet,
        backgroundColor: C.lv,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

// ── 이벤트 없음 플레이스홀더 ──────────────────────────────────────
class _EmptyEventPlaceholder extends StatelessWidget {
  final bool isKorean;
  const _EmptyEventPlaceholder({required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _EventRowPlaceholder(),
        const SizedBox(height: 8),
        _EventRowPlaceholder(),
        const SizedBox(height: 8),
        _EventRowPlaceholder(),
        const SizedBox(height: 12),
        Text(
          isKorean ? '이 날의 뜨개 일정이 없어요.\n+ 버튼으로 추가해 보세요.' : 'No events on this day.\nTap + to add one.',
          style: T.caption.copyWith(color: C.mu),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _EventRowPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: C.bd.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

// ── 이벤트 리스트 타일 ──────────────────────────────────────────
class _EventListTile extends StatelessWidget {
  final KnittingEvent event;
  final bool isKorean;
  final VoidCallback? onLongPress;

  const _EventListTile({
    required this.event,
    required this.isKorean,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(event.type);
    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  event.type.emoji,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title.isNotEmpty
                        ? event.title
                        : event.type.label(isKorean),
                    style: T.bodyBold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (event.note.isNotEmpty)
                    Text(
                      event.note,
                      style: T.caption.copyWith(color: C.mu),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (event.isAutoGenerated)
              Icon(Icons.lock_outline_rounded, size: 14, color: C.mu)
            else
              Icon(Icons.drag_handle_rounded, size: 16, color: C.mu),
          ],
        ),
      ),
    );
  }
}

// ── 이벤트 추가 BottomSheet ──────────────────────────────────────
class _AddEventSheet extends ConsumerStatefulWidget {
  final DateTime initialDate;
  final bool isKorean;
  final Future<void> Function(KnittingEvent event) onSave;

  const _AddEventSheet({
    required this.initialDate,
    required this.isKorean,
    required this.onSave,
  });

  @override
  ConsumerState<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends ConsumerState<_AddEventSheet> {
  KnittingEventType _selectedType = KnittingEventType.memo;
  late DateTime _selectedDate;
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: widget.isKorean ? const Locale('ko') : const Locale('en'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      showSaveErrorSnackBar(
        ScaffoldMessenger.of(context),
        message: widget.isKorean ? '제목을 입력해 주세요.' : 'Please enter a title.',
      );
      return;
    }
    setState(() => _saving = true);
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final event = KnittingEvent(
      id: const Uuid().v4(),
      userId: uid,
      type: _selectedType,
      title: _titleCtrl.text.trim(),
      note: _noteCtrl.text.trim(),
      date: _selectedDate,
      isAutoGenerated: false,
      createdAt: DateTime.now(),
    );
    Navigator.of(context).pop();
    await widget.onSave(event);
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = widget.isKorean;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        // 키보드 높이만큼 padding — margin이 아닌 padding이어야 overflow 없음.
        // margin은 위젯 밖에 공간 추가 → overflow 발생. padding은 안쪽 축소.
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 드래그 핸들
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: C.bd,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isKorean ? '뜨개 일정 추가' : 'Add Knitting Event',
                  style: T.h3,
                ),
                const SizedBox(height: 16),
                // 타입 선택
                Text(
                  isKorean ? '종류' : 'Type',
                  style: T.caption.copyWith(
                    color: C.tx2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _manualTypes.map((type) {
                    final isSelected = _selectedType == type;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedType = type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? C.lv.withValues(alpha: 0.14)
                              : C.lvL.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? C.lv
                                : C.lv.withValues(alpha: 0.20),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(type.emoji,
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              type.label(isKorean),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected ? C.lv : C.lvD,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // 날짜 선택
                Text(
                  isKorean ? '날짜' : 'Date',
                  style: T.caption.copyWith(
                    color: C.tx2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: C.gx,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: C.bd),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 16, color: C.lv),
                        const SizedBox(width: 8),
                        Text(
                          isKorean
                              ? '${_selectedDate.year}년 ${_selectedDate.month}월 ${_selectedDate.day}일'
                              : '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                          style: T.body.copyWith(color: C.tx),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded,
                            size: 16, color: C.mu),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 제목 입력
                TextField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    labelText: isKorean ? '제목 *' : 'Title *',
                    hintText: isKorean
                        ? '예: 코바늘 구입, 스와치 완성'
                        : 'e.g. Bought needles',
                    fillColor: C.gx,
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),
                // 메모 입력
                TextField(
                  controller: _noteCtrl,
                  decoration: InputDecoration(
                    labelText: isKorean ? '메모 (선택)' : 'Note (optional)',
                    hintText: isKorean
                        ? '간단한 메모를 남겨보세요'
                        : 'Add a short note',
                    fillColor: C.gx,
                    filled: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                // 저장 버튼
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C.lv,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      isKorean ? '저장하기' : 'Save',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
