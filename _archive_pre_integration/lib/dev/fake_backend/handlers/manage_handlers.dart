part of '../fake_backend.dart';

extension _ManageHandlers on FakeBackend {
  void _registerManage() {
    _router
      ..on('GET', '/manage/content', _manageList)
      ..on('POST', '/manage/content', _manageCreate)
      ..on('GET', '/manage/content/stats', _manageStats)
      ..on('GET', '/manage/content/:id', (r) async {
        final user = _auth(r, roles: _managers);
        return FakeResponse(200, _contentJson(_managed(r, user), manage: true));
      })
      ..on('PATCH', '/manage/content/:id', _manageUpdate)
      ..on('DELETE', '/manage/content/:id', _manageDelete)
      ..on('GET', '/manage/content/:id/file', (r) async {
        final user = _auth(r, roles: _managers);
        final c = _managed(r, user);
        if (c.current.conversionStatus != 'ready') {
          throw FakeError(
            404,
            'NOT_FOUND',
            _msg(
              r,
              'تعذّر تحويل الملف للعرض',
              'The file could not be converted for viewing',
            ),
          );
        }
        return FakeResponse(200, c.current.bytes);
      })
      ..on('POST', '/manage/content/:id/file', _replaceFile)
      ..on('GET', '/manage/content/:id/versions', _versions)
      ..on('POST', '/admin/content/:id/review', _review);
  }

  static const _managers = {'library', 'admin'};

  Iterable<FContent> _scoped(FUser user) =>
      db.content.values.where((c) => _subjectInScope(user, c.subjectId));

  /// Out-of-scope items are reported as OUT_OF_SCOPE (FR-039, FR-049).
  FContent _managed(FakeRequest r, FUser user) {
    final c = db.content[r.param('id')];
    if (c == null) throw _notFound(r);
    if (!_subjectInScope(user, c.subjectId)) {
      throw FakeError(
        403,
        'OUT_OF_SCOPE',
        _msg(
          r,
          'هذا المحتوى خارج نطاق صلاحياتك',
          'This content is outside your scope',
        ),
      );
    }
    return c;
  }

  Future<FakeResponse> _manageList(FakeRequest r) async {
    final user = _auth(r, roles: _managers);
    final text = (r.q('q') ?? '').toLowerCase();
    final items = _scoped(user).where((c) {
      final subject = db.item('subjects', c.subjectId)!['name'] as String;
      return (text.isEmpty ||
              '${c.title} $subject'.toLowerCase().contains(text)) &&
          (r.q('type') == null || c.type == r.q('type')) &&
          (r.q('status') == null || c.status == r.q('status')) &&
          (r.q('subjectId') == null || c.subjectId == r.q('subjectId'));
    }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return FakeResponse(
      200,
      _page([for (final c in items) _contentJson(c, manage: true)], r),
    );
  }

  Future<FakeResponse> _manageStats(FakeRequest r) async {
    final user = _auth(r, roles: _managers);
    final counts = <String, int>{};
    for (final c in _scoped(user)) {
      counts[c.status] = (counts[c.status] ?? 0) + 1;
    }
    return FakeResponse(200, {
      for (final s in [
        'published',
        'draft',
        'pendingReview',
        'archived',
        'hidden',
      ])
        s: counts[s] ?? 0,
    });
  }

  /// Validates metadata; publishing requires every mandatory field (FR-078).
  void _validateMetadata(
    FakeRequest r,
    FUser user,
    FContent c, {
    required bool publishing,
  }) {
    final errors = <String, String>{};
    if (c.title.trim().length < 3) errors['title'] = 'required';
    final subject = db.item('subjects', c.subjectId);
    if (subject == null) {
      errors['subjectId'] = 'required';
    } else if (!_subjectInScope(user, c.subjectId)) {
      throw FakeError(
        403,
        'OUT_OF_SCOPE',
        _msg(
          r,
          'المادة المختارة خارج نطاق صلاحياتك',
          'The selected subject is outside your scope',
        ),
      );
    }
    if (c.doctorId != null) {
      final doctor = db.item('doctors', c.doctorId);
      if (doctor == null ||
          !(doctor['subjectIds'] as List).contains(c.subjectId)) {
        errors['doctorId'] = 'invalid';
      }
    }
    if (c.termId != null && db.item('terms', c.termId) == null) {
      errors['termId'] = 'invalid';
    }
    if (c.examTypeId != null && db.item('exam-types', c.examTypeId) == null) {
      errors['examTypeId'] = 'invalid';
    }
    if (c.lectureNumber != null && c.lectureNumber! < 1) {
      errors['lectureNumber'] = 'invalid';
    }
    if (c.examYear != null &&
        (c.examYear! < 1950 || c.examYear! > now.year + 1)) {
      errors['examYear'] = 'invalid';
    }
    if (publishing) {
      if (c.type == 'lecture' && c.doctorId == null) {
        errors['doctorId'] = 'required';
      }
      if (c.type == 'exam') {
        if (c.examYear == null) errors['examYear'] = 'required';
        if (c.termId == null) errors['termId'] = 'required';
        if (c.examTypeId == null) errors['examTypeId'] = 'required';
      }
    }
    if (errors.isNotEmpty) throw _validation(r, errors);
  }

  void _applyMetadata(FakeRequest r, FContent c) {
    bool has(String k) => r.json.containsKey(k) || r.fields.containsKey(k);
    if (has('title')) c.title = r.bodyString('title') ?? '';
    if (has('description')) c.description = r.bodyString('description');
    if (has('subjectId')) c.subjectId = r.bodyString('subjectId') ?? '';
    if (has('doctorId')) c.doctorId = r.bodyString('doctorId');
    if (has('lectureNumber')) c.lectureNumber = r.bodyInt('lectureNumber');
    if (has('examYear')) c.examYear = r.bodyInt('examYear');
    if (has('termId')) c.termId = r.bodyString('termId');
    if (has('examTypeId')) c.examTypeId = r.bodyString('examTypeId');
  }

  /// Resolves the requested target status, honoring the review setting (FR-066).
  String _targetStatus(FakeRequest r, FUser user, String requested) {
    const allowed = {'draft', 'published', 'archived', 'hidden'};
    if (!allowed.contains(requested) ||
        (requested == 'hidden' && user.role != 'admin')) {
      throw _validation(r, {'status': 'invalid'});
    }
    if (requested == 'published' &&
        user.role == 'library' &&
        db.settings['requireContentReview'] == true) {
      return 'pendingReview';
    }
    return requested;
  }

  void _onStatusChanged(FContent c, String previous, FUser actor) {
    if (c.status == previous) return;
    c.updatedAt = now;
    if (c.status == 'published') {
      c.publishedAt ??= now;
      _notifyFollowers(c);
    }
    _audit(actor, 'content.${c.status}', 'content', c.id, c.title);
  }

  /// FR-071: notify students following the subject.
  void _notifyFollowers(FContent c) {
    final subject = db.item('subjects', c.subjectId)!['name'] as String;
    for (final u in db.users.values) {
      if (u.role == 'student' && u.followedSubjects.contains(c.subjectId)) {
        _notify(u.id, 'newContent', 'محتوى جديد في $subject', c.title, {
          'contentId': c.id,
        });
      }
    }
  }

  Future<FakeResponse> _manageCreate(FakeRequest r) async {
    final user = _auth(r, roles: _managers);
    final type = r.bodyString('type');
    if (type != 'lecture' && type != 'exam') {
      throw _validation(r, {'type': 'invalid'});
    }
    final c = FContent(
      id: db.newId('cnt'),
      type: type!,
      title: '',
      subjectId: '',
      status: 'draft',
      ownerId: user.id,
      createdAt: now,
    );
    _applyMetadata(r, c);
    final target = _targetStatus(r, user, r.bodyString('status') ?? 'draft');
    _validateMetadata(r, user, c, publishing: target != 'draft');
    final file = _validateFile(r, r.file);
    c.versions.add(
      FFileVersion(
        version: 1,
        bytes: r.file!.bytes,
        originalName: r.file!.name,
        mimeType: file.mimeType,
        conversionStatus: file.conversionStatus,
        uploadedAt: now,
        uploadedBy: user.actor,
      ),
    );
    c.status = target;
    db.content[c.id] = c;
    _audit(user, 'content.created', 'content', c.id, c.title);
    _onStatusChanged(c, 'draft', user);
    return FakeResponse(201, _contentJson(c, manage: true));
  }

  Future<FakeResponse> _manageUpdate(FakeRequest r) async {
    final user = _auth(r, roles: _managers);
    final c = _managed(r, user);
    final previous = c.status;
    final snapshot = c.metadataSnapshot();
    _applyMetadata(r, c);
    final requested = r.bodyString('status');
    final target = requested == null
        ? c.status
        : _targetStatus(r, user, requested);
    try {
      _validateMetadata(
        r,
        user,
        c,
        publishing: target == 'published' || target == 'pendingReview',
      );
    } on FakeError {
      // Roll back the in-memory edit — a real server would use a transaction.
      c.restoreMetadata(snapshot);
      rethrow;
    }
    c
      ..status = target
      ..updatedAt = now;
    if (requested == null) {
      _audit(user, 'content.updated', 'content', c.id, c.title);
    }
    _onStatusChanged(c, previous, user);
    return FakeResponse(200, _contentJson(c, manage: true));
  }

  Future<FakeResponse> _manageDelete(FakeRequest r) async {
    final user = _auth(r, roles: _managers);
    final c = _managed(r, user);
    db.content.remove(c.id);
    for (final u in db.users.values) {
      u.favorites.remove(c.id);
    }
    _audit(user, 'content.deleted', 'content', c.id, c.title);
    return const FakeResponse(204);
  }

  Future<FakeResponse> _replaceFile(FakeRequest r) async {
    final user = _auth(r, roles: _managers);
    final c = _managed(r, user);
    final file = _validateFile(r, r.file);
    c.versions.add(
      FFileVersion(
        version: c.current.version + 1,
        bytes: r.file!.bytes,
        originalName: r.file!.name,
        mimeType: file.mimeType,
        conversionStatus: file.conversionStatus,
        uploadedAt: now,
        uploadedBy: user.actor,
      ),
    );
    c.updatedAt = now;
    _audit(user, 'content.fileReplaced', 'content', c.id, c.title);
    return FakeResponse(200, _contentJson(c, manage: true));
  }

  Future<FakeResponse> _versions(FakeRequest r) async {
    final user = _auth(r, roles: _managers);
    final c = _managed(r, user);
    return FakeResponse(200, [
      for (final v in c.versions.reversed)
        {
          'version': v.version,
          'originalName': v.originalName,
          'sizeBytes': v.bytes.length,
          'uploadedAt': FakeBackend.iso(v.uploadedAt),
          'uploadedBy': v.uploadedBy,
          'isCurrent': identical(v, c.current),
        },
    ]);
  }

  Future<FakeResponse> _review(FakeRequest r) async {
    final admin = _auth(r, roles: {'admin'});
    final c = _managed(r, admin);
    if (c.status != 'pendingReview') {
      throw FakeError(
        409,
        'CONFLICT',
        _msg(
          r,
          'المحتوى ليس بانتظار المراجعة',
          'Content is not pending review',
        ),
      );
    }
    final approve = r.bodyString('decision') == 'approve';
    final previous = c.status;
    c
      ..status = approve ? 'published' : 'draft'
      ..reviewNote = r.bodyString('note');
    _notify(
      c.ownerId,
      'contentReviewed',
      approve ? 'تم اعتماد المحتوى' : 'تم رفض نشر المحتوى',
      c.title,
      {'contentId': c.id},
    );
    _onStatusChanged(c, previous, admin);
    return FakeResponse(200, _contentJson(c, manage: true));
  }
}
