import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BatteryScreen extends StatefulWidget {
  const BatteryScreen({super.key});

  @override
  State<BatteryScreen> createState() => _BatteryScreenState();
}

class _BatteryScreenState extends State<BatteryScreen> {
  static const _lastFullChargeKey = 'battery_last_full_charge_at';

  final Battery _battery = Battery();
  Timer? _timer;
  int? _batteryLevel;
  BatteryState? _batteryState;
  DateTime? _lastFullChargeAt;
  DateTime? _estimateTargetTime;
  Duration? _estimateDelta;
  DateTime? _lastSampleAt;
  int? _lastSampleLevel;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;

      DateTime? lastFullChargeAt;
      final stored = prefs.getInt(_lastFullChargeKey);
      if (stored != null) {
        lastFullChargeAt = DateTime.fromMillisecondsSinceEpoch(stored);
      }

      if (level >= 100) {
        lastFullChargeAt = DateTime.now();
        await prefs.setInt(
          _lastFullChargeKey,
          lastFullChargeAt.millisecondsSinceEpoch,
        );
      }

      final now = DateTime.now();
      _computeEstimate(now, level, state);

      if (!mounted) return;
      setState(() {
        _batteryLevel = level;
        _batteryState = state;
        _lastFullChargeAt = lastFullChargeAt;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '$e');
    }
  }

  void _computeEstimate(DateTime now, int level, BatteryState state) {
    if (_lastSampleAt == null || _lastSampleLevel == null) {
      _lastSampleAt = now;
      _lastSampleLevel = level;
      _estimateTargetTime = null;
      _estimateDelta = null;
      return;
    }

    final elapsedSeconds =
        now.difference(_lastSampleAt!).inSeconds.toDouble();
    final levelDelta = level - _lastSampleLevel!;

    if (elapsedSeconds <= 0 || levelDelta == 0) {
      return;
    }

    final ratePerSecond = levelDelta / elapsedSeconds;
    final targetLevel = state == BatteryState.charging ? 100 : 0;
    final remaining = targetLevel - level;

    if (ratePerSecond.abs() < 0.001) {
      _estimateTargetTime = null;
      _estimateDelta = null;
    } else {
      final secondsToTarget = remaining / ratePerSecond;
      if (secondsToTarget.isFinite && secondsToTarget > 0) {
        _estimateDelta = Duration(seconds: secondsToTarget.round());
        _estimateTargetTime = now.add(_estimateDelta!);
      } else {
        _estimateDelta = null;
        _estimateTargetTime = null;
      }
    }

    _lastSampleAt = now;
    _lastSampleLevel = level;
  }

  @override
  Widget build(BuildContext context) {
    final levelLabel =
        _batteryLevel == null ? '--' : '${_batteryLevel!.toString()}%';
    final stateLabel = _batteryState == null
        ? '--'
        : _batteryState == BatteryState.charging
            ? '充電中'
            : _batteryState == BatteryState.full
                ? '已充滿'
                : '未充電';
    final lastFullChargeLabel = _lastFullChargeAt == null
        ? '--'
        : DateFormat('yyyy/MM/dd HH:mm').format(_lastFullChargeAt!.toLocal());
    final lastFullDelta = _lastFullChargeAt == null
        ? '--'
        : _formatDuration(DateTime.now().difference(_lastFullChargeAt!));
    final estimateTimeLabel = _estimateTargetTime == null
        ? '--'
        : DateFormat('yyyy/MM/dd HH:mm').format(_estimateTargetTime!.toLocal());
    final estimateDeltaLabel =
        _estimateDelta == null ? '--' : _formatDuration(_estimateDelta!);

    return Scaffold(
      backgroundColor: const Color(0xFFF5EFE3),
      appBar: AppBar(
        title: const Text(
          '電池選單',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildInfoCard(
            title: '電池狀態',
            rows: [
              _InfoRow(label: '現在電量', value: levelLabel),
              _InfoRow(label: '充電狀態', value: stateLabel),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: '充滿紀錄',
            rows: [
              _InfoRow(label: '上次充滿電時間', value: lastFullChargeLabel),
              _InfoRow(label: '距離當下時間差', value: lastFullDelta),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: '預估時間',
            rows: [
              _InfoRow(label: '預估電量時間', value: estimateTimeLabel),
              _InfoRow(label: '距離當下時間差', value: estimateDeltaLabel),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _buildErrorBanner(_errorMessage!),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required List<Widget> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4D8C5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F1A15),
            ),
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3A1717),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF834545)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFFFB3B3)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFFFD7D7),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours <= 0) {
      return '${minutes} 分鐘';
    }
    return '${hours} 小時 ${minutes} 分鐘';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6E6457),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1F1A15),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
