part of '../fake_backend.dart';

extension _UserHandlers on FakeBackend {
  void _registerUser() {
    _router
      ..on('GET', '/me', (r) async => FakeResponse(200, _auth(r).toJson()))
      ..on('PATCH', '/me', _updateMe)
      ..on('POST', '/me/password', _changePassword)
      ..on('GET', '/me/favorites', _favorites)
      ..on('PUT', '/me/favorites/:id', (r) => _setFavorite(r, true))
      ..on('DELETE', '/me/favorites/:id', (r) => _setFavorite(r, false))
      ..on('GET', '/me/followed-subjects', (r) async {
        final user = _auth(r, roles: {'student'});
        return FakeResponse(200, user.followedSubjects.toList());
      })
      ..on('PUT', '/me/followed-subjects/:id', (r) => _setFollow(r, true))
      ..on('DELETE', '/me/followed-subjects/:id', (r) => _setFollow(r, false))
      ..on('GET', '/config', (r) async {
        _auth(r);
        return FakeResponse(200, Map<String, dynamic>.from(db.settings));
      })
      ..on('GET', '/notifications', _notifications)
      ..on('POST', '/notifications/read-all', (r) async {
        final user = _auth(r);
        for (final n in db.notifications.where((n) => n.userId == user.id)) {
          n.isRead = true;
        }
        return const FakeResponse(204);
      })
      ..on('POST', '/notifications/:id/read', (r) async {
        final user = _auth(r);
        final n = db.notifications
            .where((n) => n.id == r.param('id') && n.userId == user.id)
            .firstOrNull;
        if (n == null) throw _notFound(r);
        n.isRead = true;
        return const FakeResponse(204);
      });
  }

  Future<FakeResponse> _updateMe(FakeRequest r) async {
    final user = _auth(r);
    const allowed = {'fullName', 'phone'};
    final protected = r.json.keys.where((k) => !allowed.contains(k)).toList();
    if (protected.isNotEmpty) {
      // FR-007: protected fields are rejected, never silently ignored.
      throw FakeError(
        400,
        'PROTECTED_FIELD',
        _msg(r, 'لا يمكن تعديل هذه الحقول', 'These fields cannot be changed'),
        fields: {for (final k in protected) k: 'protected'},
      );
    }
    final name = r.bodyString('fullName');
    if (name == null || name.length < 3) {
      throw _validation(r, {'fullName': 'minLength:3'});
    }
    user
      ..fullName = name
      ..phone = r.bodyString('phone');
    _audit(user, 'user.profileUpdated', 'user', user.id, user.fullName);
    return FakeResponse(200, user.toJson());
  }

  Future<FakeResponse> _changePassword(FakeRequest r) async {
    final user = _auth(r);
    if (!user.checkPassword(r.body('currentPassword') as String? ?? '')) {
      throw FakeError(
        400,
        'VALIDATION_FAILED',
        _msg(
          r,
          'كلمة المرور الحالية غير صحيحة',
          'Current password is incorrect',
        ),
        fields: {'currentPassword': 'invalid'},
      );
    }
    final next = r.body('newPassword') as String? ?? '';
    if (next.length < 8) throw _validation(r, {'newPassword': 'minLength:8'});
    user.setPassword(next);
    final token = (r.header('authorization') ?? '').replaceFirst('Bearer ', '');
    _revokeSessions(user.id, exceptToken: token);
    _audit(user, 'user.passwordChanged', 'user', user.id, user.fullName);
    return const FakeResponse(204);
  }

  Future<FakeResponse> _favorites(FakeRequest r) async {
    final user = _auth(r, roles: {'student'});
    final items = user.favorites
        .map((id) => db.content[id])
        .whereType<FContent>()
        .where(_visibleToStudent)
        .map((c) => _contentJson(c, viewer: user))
        .toList();
    return FakeResponse(200, items);
  }

  Future<FakeResponse> _setFavorite(FakeRequest r, bool add) async {
    final user = _auth(r, roles: {'student'});
    final c = db.content[r.param('id')];
    if (c == null || !_visibleToStudent(c)) throw _notFound(r);
    add ? user.favorites.add(c.id) : user.favorites.remove(c.id);
    return const FakeResponse(204);
  }

  Future<FakeResponse> _setFollow(FakeRequest r, bool add) async {
    final user = _auth(r, roles: {'student'});
    final id = r.param('id');
    if (!_subjectActive(id)) throw _notFound(r);
    add ? user.followedSubjects.add(id) : user.followedSubjects.remove(id);
    return const FakeResponse(204);
  }

  Future<FakeResponse> _notifications(FakeRequest r) async {
    final user = _auth(r);
    final mine = db.notifications.where((n) => n.userId == user.id).toList();
    return FakeResponse(200, {
      ..._page(mine.map((n) => n.toJson()).toList(), r, 30),
      'unreadCount': mine.where((n) => !n.isRead).length,
    });
  }
}
