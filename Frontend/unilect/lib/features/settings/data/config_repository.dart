import '../../../core/models/json.dart';
import '../../../core/network/api_client.dart';
import '../domain/client_config.dart';

class ConfigRepository {
  ConfigRepository(this._api);

  final ApiClient _api;

  Future<ClientConfig> fetch() async =>
      ClientConfig.fromJson(await _api.get<Json>('/config/'));
}
