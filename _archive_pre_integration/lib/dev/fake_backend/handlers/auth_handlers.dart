part of '../fake_backend.dart';

extension _AuthHandlers on FakeBackend {
  void _registerAuth() {
    _router
      ..on('POST', '/auth/login', _login)
      ..on('POST', '/auth/refresh', _refresh)
      ..on('POST', '/auth/logout', _logout)
      ..on('POST', '/auth/password/forgot', _forgot)
      ..on('POST', '/auth/password/verify-code', _verifyCode)
      ..on('POST', '/auth/password/reset', _resetPassword)
      ..on('POST', '/device-change-requests', _createDeviceRequest);
  }

  Map<String, dynamic> _issueSession(FUser user, String installId) {
    final session = FSession(
      accessToken: db.newToken(),
      refreshToken: db.newToken(),
      userId: user.id,
      installId: installId,
      accessExpiresAt: now.add(FakeBackend.accessTtl),
    );
    db.sessions[session.accessToken] = session;
    return {
      'accessToken': session.accessToken,
      'refreshToken': session.refreshToken,
      'expiresAt': FakeBackend.iso(session.accessExpiresAt),
      'user': user.toJson(),
    };
  }

  Future<FakeResponse> _login(FakeRequest r) async {
    final email = (r.bodyString('email') ?? '').toLowerCase();
    final password = r.body('password') as String? ?? '';
    final device = Map<String, String>.from(
      (r.body('device') as Map? ?? const {}).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      ),
    );
    final user = db.users.values
        .where((u) => u.email.toLowerCase() == email)
        .firstOrNull;
    if (user == null || !user.checkPassword(password)) {
      throw FakeError(
        401,
        'INVALID_CREDENTIALS',
        _msg(
          r,
          'البريد الإلكتروني أو كلمة المرور غير صحيحة',
          'Incorrect email or password',
        ),
      );
    }
    if (user.status != 'active') {
      throw FakeError(
        403,
        'ACCOUNT_DISABLED',
        _msg(
          r,
          'هذا الحساب معطّل. تواصل مع إدارة النظام.',
          'This account is disabled. Contact the administrator.',
        ),
      );
    }
    final installId = device['installId'] ?? r.header('x-device-id') ?? '';
    if (user.role == 'student') {
      final bound = user.boundDevice;
      if (bound == null) {
        // FR-008: first trusted device is bound on first successful login.
        user.boundDevice = device;
        _deviceLog(user, 'bound', device: device);
      } else if (bound['installId'] != installId) {
        // FR-010 / FR-075: second device rejected until an admin approves.
        final ticket = db.newToken();
        db.tickets[ticket] = FTicket(
          userId: user.id,
          device: device,
          expiresAt: now.add(FakeBackend.ticketTtl),
        );
        final pending = db.deviceRequests.values
            .where((d) => d['userId'] == user.id && d['status'] == 'pending')
            .firstOrNull;
        throw FakeError(
          409,
          'DEVICE_MISMATCH',
          _msg(
            r,
            'حسابك مرتبط بجهاز آخر',
            'Your account is linked to another device',
          ),
          details: {
            'ticket': ticket,
            'ticketExpiresAt': FakeBackend.iso(now.add(FakeBackend.ticketTtl)),
            'pendingRequest': pending,
          },
        );
      }
    }
    return FakeResponse(200, _issueSession(user, installId));
  }

  Future<FakeResponse> _refresh(FakeRequest r) async {
    final token = r.bodyString('refreshToken');
    final session = db.sessions.values
        .where((s) => s.refreshToken == token)
        .firstOrNull;
    final deviceId = r.header('x-device-id');
    if (session == null || session.revoked || session.installId != deviceId) {
      throw FakeError(
        401,
        'TOKEN_REVOKED',
        _msg(r, 'انتهت الجلسة', 'Session ended'),
      );
    }
    final user = db.users[session.userId]!;
    if (user.status != 'active') {
      throw FakeError(
        403,
        'ACCOUNT_DISABLED',
        _msg(r, 'الحساب معطّل', 'Account disabled'),
      );
    }
    // Rotate: the old refresh token can never be used again.
    db.sessions.remove(session.accessToken);
    session
      ..accessToken = db.newToken()
      ..refreshToken = db.newToken()
      ..accessExpiresAt = now.add(FakeBackend.accessTtl);
    db.sessions[session.accessToken] = session;
    return FakeResponse(200, {
      'accessToken': session.accessToken,
      'refreshToken': session.refreshToken,
      'expiresAt': FakeBackend.iso(session.accessExpiresAt),
      'user': user.toJson(),
    });
  }

  Future<FakeResponse> _logout(FakeRequest r) async {
    final header = r.header('authorization') ?? '';
    db.sessions[header.replaceFirst('Bearer ', '')]?.revoked = true;
    return const FakeResponse(204);
  }

  Future<FakeResponse> _forgot(FakeRequest r) async {
    final email = (r.bodyString('email') ?? '').toLowerCase();
    final user = db.users.values
        .where((u) => u.email.toLowerCase() == email && u.status == 'active')
        .firstOrNull;
    if (user != null) {
      final code = db.newResetCode();
      db.resetCodes[email] = FResetCode(
        code: code,
        expiresAt: now.add(const Duration(minutes: 10)),
      );
      // A real server emails the code. The dev backend exposes it through a
      // debug-only hook so the flow can be tested without an inbox.
      lastIssuedResetCode = code;
    }
    return const FakeResponse(202); // Same answer either way (no enumeration).
  }

  Future<FakeResponse> _verifyCode(FakeRequest r) async {
    final email = (r.bodyString('email') ?? '').toLowerCase();
    final entry = db.resetCodes[email];
    final invalid = FakeError(
      400,
      'INVALID_RESET_CODE',
      _msg(
        r,
        'رمز التحقق غير صحيح أو منتهي الصلاحية',
        'The code is invalid or expired',
      ),
    );
    if (entry == null || now.isAfter(entry.expiresAt) || entry.attempts >= 5) {
      throw invalid;
    }
    entry.attempts++;
    if (entry.code != r.bodyString('code')) throw invalid;
    db.resetCodes.remove(email);
    final user = db.users.values.firstWhere(
      (u) => u.email.toLowerCase() == email,
    );
    final token = db.newToken();
    db.resetTokens[token] = user.id;
    return FakeResponse(200, {'resetToken': token});
  }

  Future<FakeResponse> _resetPassword(FakeRequest r) async {
    final userId = db.resetTokens.remove(r.bodyString('resetToken'));
    if (userId == null) {
      throw FakeError(
        400,
        'INVALID_RESET_CODE',
        _msg(
          r,
          'انتهت صلاحية طلب إعادة التعيين',
          'The reset request has expired',
        ),
      );
    }
    final password = r.body('newPassword') as String? ?? '';
    if (password.length < 8) {
      throw _validation(r, {'newPassword': 'minLength:8'});
    }
    final user = db.users[userId]!..setPassword(password);
    _revokeSessions(user.id);
    _audit(user, 'user.passwordReset', 'user', user.id, user.fullName);
    return const FakeResponse(204);
  }

  Future<FakeResponse> _createDeviceRequest(FakeRequest r) async {
    final ticket = db.tickets[r.bodyString('ticket')];
    if (ticket == null || now.isAfter(ticket.expiresAt)) {
      throw FakeError(
        400,
        'VALIDATION_FAILED',
        _msg(
          r,
          'انتهت صلاحية الطلب، سجّل الدخول مجدداً ثم أعد المحاولة',
          'Request expired — sign in again and retry',
        ),
      );
    }
    final user = db.users[ticket.userId]!;
    final hasPending = db.deviceRequests.values.any(
      (d) => d['userId'] == user.id && d['status'] == 'pending',
    );
    if (hasPending) {
      throw FakeError(
        409,
        'CONFLICT',
        _msg(
          r,
          'لديك طلب تغيير جهاز قيد المراجعة بالفعل',
          'You already have a pending device-change request',
        ),
      );
    }
    final reason = r.bodyString('reason');
    final request = <String, dynamic>{
      'id': db.newId('dcr'),
      'userId': user.id,
      'userName': user.fullName,
      'studentNumber': user.studentNumber,
      'status': 'pending',
      'reason': reason,
      'oldDevice': maskDevice(user.boundDevice),
      'newDevice': maskDevice(ticket.device),
      'createdAt': FakeBackend.iso(now),
      'decidedAt': null,
      'decidedBy': null,
      'decisionNote': null,
    };
    db.deviceRequests[request['id'] as String] = request;
    db.pendingDevices[request['id'] as String] = ticket.device;
    _deviceLog(user, 'changeRequested', device: ticket.device, note: reason);
    return FakeResponse(201, request);
  }
}
