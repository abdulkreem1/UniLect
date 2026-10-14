part of '../fake_backend.dart';

extension _AdminHandlers on FakeBackend {
  void _registerAdmin() {
    _router
      ..on('GET', '/admin/dashboard', _dashboard)
      ..on('GET', '/admin/users', _users)
      ..on('POST', '/admin/users', _createUser)
      ..on('GET', '/admin/users/:id', (r) async {
        _auth(r, roles: {'admin'});
        return FakeResponse(200, _user(r).toJson(admin: true));
      })
      ..on('PATCH', '/admin/users/:id', _updateUser)
      ..on('POST', '/admin/users/:id/disable', (r) => _setEnabled(r, false))
      ..on('POST', '/admin/users/:id/enable', (r) => _setEnabled(r, true))
      ..on('GET', '/admin/device-change-requests', _deviceRequests)
      ..on(
        'POST',
        '/admin/device-change-requests/:id/approve',
        (r) => _decide(r, true),
      )
      ..on(
        'POST',
        '/admin/device-change-requests/:id/reject',
        (r) => _decide(r, false),
      )
      ..on('GET', '/admin/device-logs', (r) async {
        _auth(r, roles: {'admin'});
        final userId = r.q('userId');
        final logs = db.deviceLogs
            .where((l) => userId == null || l['userId'] == userId)
            .toList();
        return FakeResponse(200, _page(logs, r, 30));
      })
      ..on('GET', '/admin/audit-logs', (r) async {
        _auth(r, roles: {'admin'});
        final type = r.q('entityType');
        final logs = db.auditLogs
            .where((l) => type == null || l['entityType'] == type)
            .toList();
        return FakeResponse(200, _page(logs, r, 30));
      })
      ..on('GET', '/admin/settings', (r) async {
        _auth(r, roles: {'admin'});
        return FakeResponse(200, Map<String, dynamic>.from(db.settings));
      })
      ..on('PUT', '/admin/settings', _saveSettings)
      ..on('GET', '/admin/reports', (r) async {
        _auth(r, roles: {'admin'});
        final status = r.q('status');
        final list =
            db.reports.values
                .where((x) => status == null || x['status'] == status)
                .toList()
              ..sort(
                (a, b) => (b['createdAt'] as String).compareTo(
                  a['createdAt'] as String,
                ),
              );
        return FakeResponse(200, list);
      })
      ..on('PATCH', '/admin/reports/:id', _updateReport);
  }

  Future<FakeResponse> _dashboard(FakeRequest r) async {
    _auth(r, roles: {'admin'});
    final users = db.users.values;
    int count(String status) =>
        db.content.values.where((c) => c.status == status).length;
    return FakeResponse(200, {
      'users': {
        'students': users.where((u) => u.role == 'student').length,
        'libraries': users.where((u) => u.role == 'library').length,
        'admins': users.where((u) => u.role == 'admin').length,
        'disabled': users.where((u) => u.status == 'disabled').length,
      },
      'content': {
        for (final s in [
          'published',
          'draft',
          'pendingReview',
          'archived',
          'hidden',
        ])
          s: count(s),
      },
      'pendingDeviceRequests': db.deviceRequests.values
          .where((d) => d['status'] == 'pending')
          .length,
      'pendingReviews': count('pendingReview'),
      'openReports': db.reports.values
          .where((x) => x['status'] == 'open' || x['status'] == 'inReview')
          .length,
    });
  }

  FUser _user(FakeRequest r) => db.users[r.param('id')] ?? (throw _notFound(r));

  Future<FakeResponse> _users(FakeRequest r) async {
    _auth(r, roles: {'admin'});
    final text = (r.q('q') ?? '').toLowerCase();
    final list = db.users.values.where((u) {
      final haystack = '${u.fullName} ${u.email} ${u.studentNumber ?? ''}'
          .toLowerCase();
      return (text.isEmpty || haystack.contains(text)) &&
          (r.q('role') == null || u.role == r.q('role')) &&
          (r.q('status') == null || u.status == r.q('status'));
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return FakeResponse(
      200,
      _page([for (final u in list) u.toJson(admin: true)], r),
    );
  }

  Map<String, List<String>>? _readScope(
    FakeRequest r,
    Map<String, String> errors,
  ) {
    final raw = r.body('scope');
    if (raw is! Map) return null;
    final unis = (raw['universityIds'] as List? ?? const []).cast<String>();
    final facs = (raw['facultyIds'] as List? ?? const []).cast<String>();
    if (unis.any((id) => db.item('universities', id) == null) ||
        facs.any((id) => db.item('faculties', id) == null)) {
      errors['scope'] = 'invalid';
    }
    return {'universityIds': unis, 'facultyIds': facs};
  }

  void _validateUserFields(
    FakeRequest r,
    String role,
    Map<String, String> errors, {
    String? exceptId,
  }) {
    final email = r.bodyString('email')?.toLowerCase();
    final name = r.bodyString('fullName');
    if (name == null || name.length < 3) errors['fullName'] = 'required';
    if (email == null ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      errors['email'] = 'invalid';
    }
    final number = r.bodyString('studentNumber');
    if (role == 'student' && number == null) {
      errors['studentNumber'] = 'required';
    }
    if (errors.isNotEmpty) return;
    for (final u in db.users.values) {
      if (u.id == exceptId) continue;
      if (u.email.toLowerCase() == email) errors['email'] = 'taken';
      if (role == 'student' && number != null && u.studentNumber == number) {
        errors['studentNumber'] = 'taken';
      }
    }
  }

  Future<FakeResponse> _createUser(FakeRequest r) async {
    final admin = _auth(r, roles: {'admin'});
    final role = r.bodyString('role') ?? '';
    final errors = <String, String>{};
    if (!const {'student', 'library', 'admin'}.contains(role)) {
      errors['role'] = 'invalid';
    }
    _validateUserFields(r, role, errors);
    final password = r.body('initialPassword') as String? ?? '';
    if (password.length < 8) errors['initialPassword'] = 'minLength:8';
    final scope = role == 'library' ? _readScope(r, errors) : null;
    if (role == 'library' &&
        (scope == null ||
            (scope['universityIds']!.isEmpty &&
                scope['facultyIds']!.isEmpty))) {
      errors['scope'] = 'required';
    }
    if (errors.isNotEmpty) {
      final taken = errors.values.contains('taken');
      throw FakeError(
        taken ? 409 : 400,
        taken ? 'CONFLICT' : 'VALIDATION_FAILED',
        taken
            ? _msg(
                r,
                'البريد الإلكتروني أو الرقم الجامعي مستخدم مسبقاً',
                'Email or student number already in use',
              )
            : _msg(
                r,
                'يرجى تصحيح الحقول المحددة',
                'Please fix the highlighted fields',
              ),
        fields: errors,
      );
    }
    final user = FUser(
      id: db.newId('usr'),
      publicCode: db.newPublicCode(),
      role: role,
      fullName: r.bodyString('fullName')!,
      email: r.bodyString('email')!.toLowerCase(),
      studentNumber: role == 'student' ? r.bodyString('studentNumber') : null,
      phone: r.bodyString('phone'),
      scope: scope,
      createdAt: now,
    )..setPassword(password);
    db.users[user.id] = user;
    _audit(admin, 'user.created', 'user', user.id, user.fullName);
    return FakeResponse(201, user.toJson(admin: true));
  }

  Future<FakeResponse> _updateUser(FakeRequest r) async {
    final admin = _auth(r, roles: {'admin'});
    final user = _user(r);
    final errors = <String, String>{};
    _validateUserFields(r, user.role, errors, exceptId: user.id);
    final scope = user.role == 'library' ? _readScope(r, errors) : null;
    if (errors.isNotEmpty) {
      final taken = errors.values.contains('taken');
      throw FakeError(
        taken ? 409 : 400,
        taken ? 'CONFLICT' : 'VALIDATION_FAILED',
        _msg(
          r,
          'يرجى تصحيح الحقول المحددة',
          'Please fix the highlighted fields',
        ),
        fields: errors,
      );
    }
    user
      ..fullName = r.bodyString('fullName')!
      ..email = r.bodyString('email')!.toLowerCase()
      ..phone = r.bodyString('phone');
    if (user.role == 'student') {
      user.studentNumber = r.bodyString('studentNumber');
    }
    if (scope != null) user.scope = scope;
    _audit(admin, 'user.updated', 'user', user.id, user.fullName);
    return FakeResponse(200, user.toJson(admin: true));
  }

  Future<FakeResponse> _setEnabled(FakeRequest r, bool enabled) async {
    final admin = _auth(r, roles: {'admin'});
    final user = _user(r);
    if (user.id == admin.id) {
      throw FakeError(
        409,
        'CONFLICT',
        _msg(r, 'لا يمكنك تعطيل حسابك', 'You cannot disable your own account'),
      );
    }
    user.status = enabled ? 'active' : 'disabled';
    if (!enabled) _revokeSessions(user.id); // FR-005: disabled cannot sign in.
    _audit(
      admin,
      enabled ? 'user.enabled' : 'user.disabled',
      'user',
      user.id,
      user.fullName,
    );
    return FakeResponse(200, user.toJson(admin: true));
  }

  Future<FakeResponse> _deviceRequests(FakeRequest r) async {
    _auth(r, roles: {'admin'});
    final status = r.q('status');
    final oldest = r.q('sort') == 'oldest';
    final list =
        db.deviceRequests.values
            .where((d) => status == null || d['status'] == status)
            .toList()
          ..sort((a, b) {
            final c = (a['createdAt'] as String).compareTo(
              b['createdAt'] as String,
            );
            return oldest ? c : -c;
          });
    return FakeResponse(200, list);
  }

  /// FR-012..015, FR-070: decision recorded with admin + date; on approval the
  /// old device is unbound, its sessions revoked and the new device bound.
  Future<FakeResponse> _decide(FakeRequest r, bool approve) async {
    final admin = _auth(r, roles: {'admin'});
    final request = db.deviceRequests[r.param('id')];
    if (request == null) throw _notFound(r);
    if (request['status'] != 'pending') {
      throw FakeError(
        409,
        'CONFLICT',
        _msg(
          r,
          'تم اتخاذ قرار بهذا الطلب مسبقاً',
          'This request was already decided',
        ),
      );
    }
    final student = db.users[request['userId'] as String]!;
    final note = r.bodyString('note');
    request
      ..['status'] = approve ? 'approved' : 'rejected'
      ..['decidedAt'] = FakeBackend.iso(now)
      ..['decidedBy'] = admin.actor
      ..['decisionNote'] = note;
    final newDevice = db.pendingDevices.remove(request['id']);
    if (approve && newDevice != null) {
      _deviceLog(student, 'unbound', device: student.boundDevice, actor: admin);
      _revokeSessions(student.id);
      student.boundDevice = newDevice;
      _deviceLog(
        student,
        'approved',
        device: newDevice,
        actor: admin,
        note: note,
      );
      _notify(
        student.id,
        'deviceChangeApproved',
        'تمت الموافقة على تغيير الجهاز',
        'يمكنك الآن استخدام حسابك على جهازك الجديد.',
      );
    } else {
      _deviceLog(
        student,
        'rejected',
        device: newDevice,
        actor: admin,
        note: note,
      );
      _notify(
        student.id,
        'deviceChangeRejected',
        'تم رفض طلب تغيير الجهاز',
        note ?? 'تواصل مع إدارة النظام لمزيد من التفاصيل.',
      );
    }
    _audit(
      admin,
      approve ? 'device.approved' : 'device.rejected',
      'device',
      request['id'] as String,
      student.fullName,
    );
    return FakeResponse(200, request);
  }

  Future<FakeResponse> _saveSettings(FakeRequest r) async {
    final admin = _auth(r, roles: {'admin'});
    final max = r.bodyInt('maxUploadSizeMb');
    final exts = (r.body('allowedExtensions') as List?)?.cast<String>();
    final errors = <String, String>{};
    if (max == null || max < 1 || max > 200) {
      errors['maxUploadSizeMb'] = 'range:1-200';
    }
    if (exts == null || exts.isEmpty) errors['allowedExtensions'] = 'required';
    if (errors.isNotEmpty) throw _validation(r, errors);
    db.settings
      ..['maxUploadSizeMb'] = max
      ..['allowedExtensions'] = exts!
          .map((e) => e.toLowerCase())
          .toSet()
          .toList()
      ..['requireContentReview'] = r.body('requireContentReview') == true
      ..['watermarkEnabled'] = r.body('watermarkEnabled') == true
      ..['screenCaptureProtection'] = r.body('screenCaptureProtection') == true;
    _audit(
      admin,
      'settings.updated',
      'settings',
      'settings',
      'System settings',
    );
    return FakeResponse(200, Map<String, dynamic>.from(db.settings));
  }

  Future<FakeResponse> _updateReport(FakeRequest r) async {
    final admin = _auth(r, roles: {'admin'});
    final report = db.reports[r.param('id')] ?? (throw _notFound(r));
    final status = r.bodyString('status');
    if (!const {'open', 'inReview', 'resolved', 'dismissed'}.contains(status)) {
      throw _validation(r, {'status': 'invalid'});
    }
    report['status'] = status;
    (report['history'] as List).add({
      'status': status,
      'note': r.bodyString('note'),
      'actor': admin.actor,
      'at': FakeBackend.iso(now),
    });
    final reporterId = (report['reporter'] as Map)['id'] as String;
    _notify(
      reporterId,
      'reportUpdated',
      'تحديث على بلاغك',
      report['contentTitle'] as String,
    );
    _audit(
      admin,
      'report.updated',
      'report',
      report['id'] as String,
      report['contentTitle'] as String,
    );
    return FakeResponse(200, report);
  }
}
