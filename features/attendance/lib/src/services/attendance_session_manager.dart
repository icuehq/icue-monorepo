import 'package:flutter/foundation.dart';
import 'package:icue_face_sdk/icue_face_sdk.dart';

enum ProfileState {
  ready,
  notEnrolled,
  profileIncompatible,
  requiresReenrollment,
}

enum AttendanceState {
  unreviewed,
  present,
  possiblyAbsent,
  absent,
}

enum MarkSource {
  face,
  manual,
  none,
}

class StudentSessionState {
  StudentSessionState({
    required this.personId,
    required this.studentName,
    required this.profileState,
    this.attendanceState = AttendanceState.unreviewed,
    this.markSource = MarkSource.none,
    this.lastMatchScore,
    this.confirmedTimestamp,
  });

  final String personId;
  final String studentName;
  final ProfileState profileState;
  AttendanceState attendanceState;
  MarkSource markSource;
  double? lastMatchScore;
  DateTime? confirmedTimestamp;

  bool get isPresent => attendanceState == AttendanceState.present;
  bool get isEligibleForAutoAttendance => profileState == ProfileState.ready;
}

class TrackObservation {
  const TrackObservation({
    required this.personId,
    required this.score,
    required this.timestamp,
  });

  final String personId;
  final double score;
  final DateTime timestamp;
}

class AttendanceSessionManager {
  AttendanceSessionManager({
    required this.sessionId,
    required this.rosterRevision,
    required this.modelContractId,
    required List<StudentSessionState> initialRoster,
    this.requiredMatchesCount = 3,
    this.timeWindowDuration = const Duration(seconds: 2),
    this.minObservationInterval = const Duration(milliseconds: 200),
  }) {
    for (final s in initialRoster) {
      _studentMap[s.personId] = s;
    }
  }

  final String sessionId;
  final String rosterRevision;
  final String modelContractId;
  final int requiredMatchesCount;
  final Duration timeWindowDuration;
  final Duration minObservationInterval;

  final Map<String, StudentSessionState> _studentMap = {};
  final Map<int, List<TrackObservation>> _trackHistory = {};
  final Set<int> _confirmedTrackIds = {};
  int _unrecognizedTrackCount = 0;

  Map<String, StudentSessionState> get studentMap =>
      Map.unmodifiable(_studentMap);
  int get unrecognizedTrackCount => _unrecognizedTrackCount;

  /// Eligible Roster = { s | s.profileState == ready }
  List<StudentSessionState> get eligibleRoster =>
      _studentMap.values.where((s) => s.isEligibleForAutoAttendance).toList();

  /// Process observation frame results from native matcher
  void processObservationFrame({
    required List<FaceRecognitionResult> results,
    required String frameRosterRevision,
  }) {
    if (frameRosterRevision != rosterRevision) {
      debugPrint(
        'Warning: Frame rosterRevision mismatch ($frameRosterRevision vs $rosterRevision). Frame discarded.',
      );
      return;
    }

    final DateTime now = DateTime.now();

    for (final result in results) {
      final int trackingId = result.boundingBox.trackingId ?? -1;

      // Skip processing already confirmed tracks
      if (trackingId != -1 && _confirmedTrackIds.contains(trackingId)) {
        continue;
      }

      if (!result.matched || result.personId == null) {
        if (trackingId != -1 && !_trackHistory.containsKey(trackingId)) {
          _unrecognizedTrackCount++;
        }
        continue;
      }

      final String personId = result.personId!;
      final StudentSessionState? student = _studentMap[personId];

      if (student == null || !student.isEligibleForAutoAttendance) {
        continue;
      }

      if (trackingId != -1) {
        final observations = _trackHistory.putIfAbsent(trackingId, () => []);

        // Enforce minimum observation interval
        if (observations.isNotEmpty) {
          final lastObs = observations.last;
          if (now.difference(lastObs.timestamp) < minObservationInterval) {
            continue;
          }
          // Reset track if conflicting identity occurs
          if (lastObs.personId != personId) {
            observations.clear();
          }
        }

        observations.add(
          TrackObservation(
            personId: personId,
            score: result.score,
            timestamp: now,
          ),
        );

        // Prune observations outside time window
        observations.removeWhere(
          (obs) => now.difference(obs.timestamp) > timeWindowDuration,
        );

        // Check M-in-T temporal condition
        if (observations.length >= requiredMatchesCount) {
          _confirmedTrackIds.add(trackingId);
          student.attendanceState = AttendanceState.present;
          student.markSource = MarkSource.face;
          student.lastMatchScore = result.score;
          student.confirmedTimestamp = now;
        }
      } else {
        // Direct match fallback without trackingId
        student.attendanceState = AttendanceState.present;
        student.markSource = MarkSource.face;
        student.lastMatchScore = result.score;
        student.confirmedTimestamp = now;
      }
    }
  }

  /// Manually override student attendance
  void setManualAttendance(String personId, bool isPresent) {
    final student = _studentMap[personId];
    if (student != null) {
      student.attendanceState = isPresent
          ? AttendanceState.present
          : AttendanceState.absent;
      student.markSource = MarkSource.manual;
      student.confirmedTimestamp = DateTime.now();
    }
  }

  /// Finalize attendance calculation
  AttendanceResult finalizeSession({
    required AttendanceMode mode,
    int photosProcessed = 1,
    List<String> capturedImagePaths = const [],
  }) {
    final List<AttendanceRecord> presentRecords = [];
    final List<String> possiblyAbsentIds = [];

    for (final student in _studentMap.values) {
      if (student.isPresent) {
        presentRecords.add(
          AttendanceRecord(
            personId: student.personId,
            confidenceScore: student.lastMatchScore ?? 1.0,
            timestamp: student.confirmedTimestamp ?? DateTime.now(),
          ),
        );
      } else if (student.isEligibleForAutoAttendance) {
        // Only READY profiles enter possiblyAbsent calculation
        student.attendanceState = AttendanceState.possiblyAbsent;
        possiblyAbsentIds.add(student.personId);
      }
    }

    return AttendanceResult(
      present: presentRecords,
      absentPersonIds: possiblyAbsentIds,
      unrecognizedFaceCount: _unrecognizedTrackCount,
      totalRosterCount: eligibleRoster.length,
      sessionStartTime: DateTime.now(),
      sessionEndTime: DateTime.now(),
      mode: mode,
      photosProcessed: photosProcessed,
      capturedImagePaths: capturedImagePaths,
    );
  }

  void resetTrackHistory() {
    _trackHistory.clear();
    _confirmedTrackIds.clear();
  }
}
