part of '../fake_backend.dart';

extension _ContentHandlers on FakeBackend {
  void _registerContent() {
    _router
      ..on('GET', '/subjects/:id/lectures', _lectures)
      ..on('GET', '/subjects/:id/exams', _exams)
      ..on('GET', '/content/search', _search)
      ..on('GET', '/content/:id', _detail)
      ..on('GET', '/content/:id/file', _file)
      ..on('POST', '/content/:id/reports', _report);
  }

  Iterable<FContent> _studentVisible() =>
      db.content.values.where(_visibleToStudent);

  Future<FakeResponse> _lectures(FakeRequest r) async {
    final user = _auth(r, roles: {'student'});
    final doctorId = r.q('doctorId');
    final items =
        _studentVisible()
            .where(
              (c) =>
                  c.type == 'lecture' &&
                  c.subjectId == r.param('id') &&
                  (doctorId == null || c.doctorId == doctorId),
            )
            .toList()
          ..sort(FakeBackend._contentOrder);
    return FakeResponse(200, [
      for (final c in items) _contentJson(c, viewer: user),
    ]);
  }

  Future<FakeResponse> _exams(FakeRequest r) async {
    final user = _auth(r, roles: {'student'});
    final year = int.tryParse(r.q('examYear') ?? '');
    final items =
        _studentVisible()
            .where(
              (c) =>
                  c.type == 'exam' &&
                  c.subjectId == r.param('id') &&
                  (year == null || c.examYear == year) &&
                  (r.q('termId') == null || c.termId == r.q('termId')) &&
                  (r.q('examTypeId') == null ||
                      c.examTypeId == r.q('examTypeId')) &&
                  (r.q('doctorId') == null || c.doctorId == r.q('doctorId')),
            )
            .toList()
          ..sort((a, b) => (b.examYear ?? 0).compareTo(a.examYear ?? 0));
    return FakeResponse(200, [
      for (final c in items) _contentJson(c, viewer: user),
    ]);
  }

  Future<FakeResponse> _search(FakeRequest r) async {
    final user = _auth(r, roles: {'student'});
    final text = (r.q('q') ?? '').toLowerCase();
    final items = _studentVisible().where((c) {
      final path = _pathOfSubject(c.subjectId)!;
      final doctor = db.item('doctors', c.doctorId)?['name'] as String? ?? '';
      final haystack = [
        c.title,
        c.description ?? '',
        path.subject['name'],
        doctor,
      ].join(' ').toLowerCase();
      return (text.isEmpty || haystack.contains(text)) &&
          (r.q('type') == null || c.type == r.q('type')) &&
          (r.q('universityId') == null ||
              path.university['id'] == r.q('universityId')) &&
          (r.q('facultyId') == null ||
              path.faculty['id'] == r.q('facultyId')) &&
          (r.q('yearId') == null || path.year['id'] == r.q('yearId')) &&
          (r.q('subjectId') == null || c.subjectId == r.q('subjectId')) &&
          (r.q('doctorId') == null || c.doctorId == r.q('doctorId'));
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return FakeResponse(
      200,
      _page([for (final c in items) _contentJson(c, viewer: user)], r),
    );
  }

  FContent _studentContent(FakeRequest r) {
    final c = db.content[r.param('id')];
    // Unauthorized and missing look identical (FR-056).
    if (c == null || !_visibleToStudent(c)) throw _notFound(r);
    return c;
  }

  Future<FakeResponse> _detail(FakeRequest r) async {
    final user = _auth(r, roles: {'student'});
    return FakeResponse(200, _contentJson(_studentContent(r), viewer: user));
  }

  Future<FakeResponse> _file(FakeRequest r) async {
    _auth(r, roles: {'student'});
    final c = _studentContent(r);
    if (c.current.conversionStatus != 'ready') {
      throw FakeError(
        404,
        'NOT_FOUND',
        _msg(r, 'الملف غير جاهز للعرض', 'The file is not ready for viewing'),
      );
    }
    return FakeResponse(200, c.current.bytes);
  }

  Future<FakeResponse> _report(FakeRequest r) async {
    final user = _auth(r, roles: {'student'});
    final c = _studentContent(r);
    final reason = r.bodyString('reason');
    if (!const {
      'wrongFile',
      'duplicate',
      'inappropriate',
      'other',
    }.contains(reason)) {
      throw _validation(r, {'reason': 'invalid'});
    }
    final report = <String, dynamic>{
      'id': db.newId('rep'),
      'contentId': c.id,
      'contentTitle': c.title,
      'reason': reason,
      'note': r.bodyString('note'),
      'status': 'open',
      'reporter': user.actor,
      'createdAt': FakeBackend.iso(now),
      'history': <Map<String, dynamic>>[],
    };
    db.reports[report['id'] as String] = report;
    return FakeResponse(201, report);
  }
}
