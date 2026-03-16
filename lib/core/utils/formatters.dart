import 'package:intl/intl.dart';

import '../../models/device_models.dart';

String formatRelativeTime(DateTime? value) {
  if (value == null) {
    return 'Chua co du lieu';
  }

  final difference = DateTime.now().difference(value);

  if (difference.inSeconds < 60) {
    return 'Vua xong';
  }
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes} phut truoc';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours} gio truoc';
  }
  return DateFormat('dd/MM/yyyy HH:mm').format(value);
}

String formatDateTime(DateTime? value) {
  if (value == null) {
    return 'Chua cap nhat';
  }
  return DateFormat('dd/MM/yyyy HH:mm:ss').format(value);
}

String formatTemperature(double? value) {
  if (value == null) {
    return '--';
  }
  return '${value.toStringAsFixed(1)} C';
}

String formatHumidity(double? value) {
  if (value == null) {
    return '--';
  }
  return '${value.toStringAsFixed(0)} %';
}

String formatLight(double? value) {
  if (value == null) {
    return '--';
  }
  return value.toStringAsFixed(0);
}

String formatPercent(double? value) {
  if (value == null) {
    return '--';
  }
  return '${value.toStringAsFixed(0)} %';
}

String relayStateLabel(bool isOn) => isOn ? 'Dang bat' : 'Dang tat';

String modeLabel(String mode) {
  switch (mode.toLowerCase()) {
    case 'auto':
      return 'Tu dong';
    default:
      return 'Thu cong';
  }
}

String sourceLabel(String? source) {
  if (source == null || source.isEmpty) {
    return 'Chua xac dinh';
  }

  final normalized = source.toLowerCase();
  if (normalized.contains('button')) {
    return 'Nut vat ly';
  }
  if (normalized.contains('auto')) {
    return 'Tu dong';
  }
  if (normalized.contains('esp')) {
    return 'ESP32';
  }
  if (normalized.contains('app')) {
    return 'Ung dung';
  }
  return source;
}

String historyTitle(HistoryEntry entry, Map<String, String> relayLabels) {
  final targetName = relayDisplayName(entry.target, relayLabels);
  switch (entry.eventType.toLowerCase()) {
    case 'command_sent':
      return 'Gui lenh toi $targetName';
    case 'relay_change':
      return '$targetName thay doi trang thai';
    default:
      return '$targetName cap nhat';
  }
}

String historySubtitle(HistoryEntry entry) {
  final newValue = entry.newValue;
  if (newValue == null) {
    return sourceLabel(entry.source);
  }
  return '${newValue ? 'Bat' : 'Tat'} qua ${sourceLabel(entry.source)}';
}
