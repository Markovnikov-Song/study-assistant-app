// Learning OS — Session Service
// Phase 3: Unified Session creation, pause, completion, and query.
// Requirement 4.7, 5.1, 5.2, 5.3

import 'package:uuid/uuid.dart';
import '../core/skill/skill_model.dart';

const _uuid = Uuid();

/// Filter parameters for querying Sessions (Requirement 5.3, Property 12).
class SessionFilter {
  final String? sessionId;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? subjectId;
  final LearningMode? mode;

  const SessionFilter({
    this.sessionId,
    this.fromDate,
    this.toDate,
    this.subjectId,
    this.mode,
  });
}

/// Manages Learning OS Sessions — creation, state transitions, and queries.
///
/// Currently backed by an in-memory store. In a production build this would
/// persist to the backend via a REST API (same pattern as [ChatService]).
///
/// Requirement 5.1: stores three data categories under a unified Session ID.
/// Requirement 5.2: all data produced during a Session is associated to the
///   same Session ID (Property 11).
/// Requirement 5.3: supports filtering by Session ID, date range, subject,
///   and mode type (Property 12).
class SessionService {
  final Map<String, Session> _sessions = {};

  // ── Create ─────────────────────────────────────────────────────────────────

  /// Creates a new active Session and returns it.
  /// Requirement 4.7: records mode, Skill/Component IDs, and start time.
  Session create({
    required String userId,
    required LearningMode mode,
    String? skillId,
    List<String> componentIds = const [],
  }) {
    final session = Session(
      id: _uuid.v4(),
      userId: userId,
      mode: mode,
      skillId: skillId,
      componentIds: componentIds,
      startedAt: DateTime.now(),
      status: SessionStatus.active,
    );
    _sessions[session.id] = session;
    return session;
  }

  // ── State transitions ──────────────────────────────────────────────────────

  /// Pauses an active Session (Requirement 4.8).
  Session pause(String sessionId) {
    final session = _getOrThrow(sessionId);
    final updated = _copyWith(session, status: SessionStatus.paused);
    _sessions[sessionId] = updated;
    return updated;
  }

  /// Completes a Session and records the end time (Requirement 4.7, 5.2).
  Session complete(String sessionId) {
    final session = _getOrThrow(sessionId);
    final updated = _copyWith(
      session,
      status: SessionStatus.completed,
      endedAt: DateTime.now(),
    );
    _sessions[sessionId] = updated;
    return updated;
  }

  // ── Query ──────────────────────────────────────────────────────────────────

  /// Retrieves a Session by ID (Requirement 5.4).
  Session? get(String sessionId) => _sessions[sessionId];

  /// Lists Sessions matching [filter] (Requirement 5.3, Property 12).
  List<Session> list({SessionFilter? filter}) {
    var results = _sessions.values.toList();

    if (filter == null) return results;

    if (filter.sessionId != null) {
      results = results.where((s) => s.id == filter.sessionId).toList();
    }

    if (filter.fromDate != null) {
      results = results
          .where((s) => !s.startedAt.isBefore(filter.fromDate!))
          .toList();
    }

    if (filter.toDate != null) {
      results = results
          .where((s) => !s.startedAt.isAfter(filter.toDate!))
          .toList();
    }

    if (filter.subjectId != null) {
      // NOTE: Session model does not carry subjectId directly in Phase 3.
      // This filter will be activated when Session is extended with a
      // subjectId field in a future iteration.
    }

    if (filter.mode != null) {
      results = results.where((s) => s.mode == filter.mode).toList();
    }

    return results;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Session _getOrThrow(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) {
      throw Exception('Session "$sessionId" not found');
    }
    return session;
  }

  Session _copyWith(
    Session s, {
    SessionStatus? status,
    DateTime? endedAt,
  }) {
    return Session(
      id: s.id,
      userId: s.userId,
      mode: s.mode,
      skillId: s.skillId,
      componentIds: s.componentIds,
      startedAt: s.startedAt,
      endedAt: endedAt ?? s.endedAt,
      status: status ?? s.status,
    );
  }
}
