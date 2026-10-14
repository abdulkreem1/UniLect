part of '../fake_backend.dart';

/// Parent field of each kind, used for `parentId` filtering and validation.
const _parentField = <String, (String field, String parentKind)>{
  'faculties': ('universityId', 'universities'),
  'years': ('facultyId', 'faculties'),
  'specializations': ('facultyId', 'faculties'),
  'subjects': ('facultyId', 'faculties'),
};

extension _StructureHandlers on FakeBackend {
  void _registerStructure() {
    _router
      ..on('GET', '/universities', (r) async {
        final user = _auth(r);
        return _items(
          'universities',
          user,
          (u) => _inScopeOrPublic(user, universityId: u['id'] as String),
        );
      })
      ..on('GET', '/universities/:id/faculties', (r) async {
        final user = _auth(r);
        return _items(
          'faculties',
          user,
          (f) =>
              f['universityId'] == r.param('id') &&
              _inScopeOrPublic(user, facultyId: f['id'] as String),
        );
      })
      ..on('GET', '/faculties/:id/years', (r) async {
        final user = _auth(r);
        return _items(
          'years',
          user,
          (y) =>
              y['facultyId'] == r.param('id') &&
              _inScopeOrPublic(user, facultyId: r.param('id')),
        );
      })
      ..on('GET', '/faculties/:id/specializations', (r) async {
        final user = _auth(r);
        return _items(
          'specializations',
          user,
          (s) =>
              s['facultyId'] == r.param('id') &&
              _inScopeOrPublic(user, facultyId: r.param('id')),
        );
      })
      ..on('GET', '/years/:id/subjects', (r) async {
        final user = _auth(r);
        final spec = r.q('specializationId');
        return _items('subjects', user, (s) {
          final specs = (s['specializationIds'] as List).cast<String>();
          return s['yearId'] == r.param('id') &&
              _inScopeOrPublic(user, facultyId: s['facultyId'] as String) &&
              (spec == null || specs.isEmpty || specs.contains(spec));
        });
      })
      ..on('GET', '/subjects/:id', (r) async {
        final user = _auth(r);
        final s = db.item('subjects', r.param('id'));
        final visible =
            s != null &&
            (user.role != 'student' || _subjectActive(s['id'] as String));
        if (!visible) throw _notFound(r);
        return FakeResponse(200, s);
      })
      ..on('GET', '/subjects/:id/doctors', (r) async {
        final user = _auth(r);
        return _items(
          'doctors',
          user,
          (d) => (d['subjectIds'] as List).contains(r.param('id')),
        );
      })
      ..on('GET', '/terms', (r) async => _items('terms', _auth(r), (_) => true))
      ..on(
        'GET',
        '/exam-types',
        (r) async => _items('exam-types', _auth(r), (_) => true),
      )
      // ── admin ──
      ..on('GET', '/admin/structure/:kind', _adminList)
      ..on('POST', '/admin/structure/:kind', _adminCreate)
      ..on('POST', '/admin/structure/:kind/reorder', _adminReorder)
      ..on('PATCH', '/admin/structure/:kind/:id', _adminUpdate);
  }

  bool _inScopeOrPublic(FUser user, {String? universityId, String? facultyId}) {
    if (user.role != 'library') return true;
    if (facultyId != null) return _inScope(user, facultyId: facultyId);
    // A university is listed if it or any of its faculties is in scope.
    return _inScope(user, universityId: universityId) ||
        db.structure['faculties']!.values.any(
          (f) =>
              f['universityId'] == universityId &&
              _inScope(user, facultyId: f['id'] as String),
        );
  }

  /// Students see active items only; managers see everything (sorted).
  FakeResponse _items(
    String kind,
    FUser user,
    bool Function(Map<String, dynamic>) where,
  ) {
    final list =
        db.structure[kind]!.values
            .where(where)
            .where((i) => user.role != 'student' || i['isActive'] == true)
            .toList()
          ..sort(FakeBackend._bySort);
    return FakeResponse(200, list);
  }

  String _kind(FakeRequest r) {
    final kind = r.param('kind');
    if (!FakeDb.structureKinds.contains(kind)) throw _notFound(r);
    return kind;
  }

  Future<FakeResponse> _adminList(FakeRequest r) async {
    _auth(r, roles: {'admin'});
    final kind = _kind(r);
    final parentId = r.q('parentId');
    final parent = _parentField[kind];
    final list = db.structure[kind]!.values.where((i) {
      if (parentId == null) return true;
      if (kind == 'doctors') {
        return (i['subjectIds'] as List).contains(parentId);
      }
      return parent != null && i[parent.$1] == parentId;
    }).toList()..sort(FakeBackend._bySort);
    return FakeResponse(200, list);
  }

  Map<String, dynamic> _readItem(
    FakeRequest r,
    String kind,
    Map<String, dynamic>? existing,
  ) {
    final name = r.bodyString('name') ?? existing?['name'] as String?;
    final errors = <String, String>{};
    if (name == null || name.length < 2) errors['name'] = 'required';
    final item = <String, dynamic>{
      ...?existing,
      'name': name,
      'isActive': r.body('isActive') as bool? ?? existing?['isActive'] ?? true,
      'sortOrder':
          r.bodyInt('sortOrder') ??
          existing?['sortOrder'] ??
          db.structure[kind]!.length + 1,
    };
    // FR-017: every child must reference an existing parent.
    final parent = _parentField[kind];
    if (parent != null) {
      final parentId =
          r.bodyString(parent.$1) ?? existing?[parent.$1] as String?;
      if (db.item(parent.$2, parentId) == null) errors[parent.$1] = 'invalid';
      item[parent.$1] = parentId;
    }
    if (kind == 'years') {
      item['level'] = r.bodyInt('level') ?? existing?['level'] ?? 1;
    }
    if (kind == 'subjects') {
      final yearId = r.bodyString('yearId') ?? existing?['yearId'] as String?;
      final year = db.item('years', yearId);
      if (year == null || year['facultyId'] != item['facultyId']) {
        errors['yearId'] = 'invalid';
      }
      final specs =
          (r.body('specializationIds') as List?)?.cast<String>() ??
          (existing?['specializationIds'] as List?)?.cast<String>() ??
          <String>[];
      if (specs.any(
        (s) => db.item('specializations', s)?['facultyId'] != item['facultyId'],
      )) {
        errors['specializationIds'] = 'invalid';
      }
      item
        ..['yearId'] = yearId
        ..['specializationIds'] = specs
        ..['code'] = r.json.containsKey('code')
            ? r.bodyString('code')
            : existing?['code'];
    }
    if (kind == 'doctors') {
      final subjects =
          (r.body('subjectIds') as List?)?.cast<String>() ??
          (existing?['subjectIds'] as List?)?.cast<String>() ??
          <String>[];
      if (subjects.any((s) => db.item('subjects', s) == null)) {
        errors['subjectIds'] = 'invalid';
      }
      item['subjectIds'] = subjects;
    }
    if (errors.isNotEmpty) throw _validation(r, errors);
    return item;
  }

  Future<FakeResponse> _adminCreate(FakeRequest r) async {
    final admin = _auth(r, roles: {'admin'});
    final kind = _kind(r);
    final item = _readItem(r, kind, null)
      ..['id'] = db.newId(kind.substring(0, 3));
    db.structure[kind]![item['id'] as String] = item;
    _audit(
      admin,
      'structure.created',
      'structure',
      item['id'] as String,
      item['name'] as String,
    );
    return FakeResponse(201, item);
  }

  Future<FakeResponse> _adminUpdate(FakeRequest r) async {
    final admin = _auth(r, roles: {'admin'});
    final kind = _kind(r);
    final existing = db.item(kind, r.param('id'));
    if (existing == null) throw _notFound(r);
    final item = _readItem(r, kind, existing);
    db.structure[kind]![item['id'] as String] = item;
    final toggled = existing['isActive'] != item['isActive'];
    _audit(
      admin,
      toggled
          ? (item['isActive'] == true
                ? 'structure.activated'
                : 'structure.deactivated')
          : 'structure.updated',
      'structure',
      item['id'] as String,
      item['name'] as String,
    );
    return FakeResponse(200, item);
  }

  Future<FakeResponse> _adminReorder(FakeRequest r) async {
    final admin = _auth(r, roles: {'admin'});
    final kind = _kind(r);
    final ids = (r.body('ids') as List? ?? const []).cast<String>();
    for (var i = 0; i < ids.length; i++) {
      db.item(kind, ids[i])?['sortOrder'] = i + 1;
    }
    _audit(admin, 'structure.reordered', 'structure', kind, kind);
    return const FakeResponse(204);
  }
}
