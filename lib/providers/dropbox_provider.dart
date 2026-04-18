import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/dropbox/data/dropbox_api_client.dart';
import '../features/dropbox/data/dropbox_auth_provider.dart';

export '../features/dropbox/data/dropbox_auth_provider.dart'
    show DropboxAuthState;

final dropboxApiClientProvider = Provider<DropboxApiClient>(
  (ref) => DropboxApiClient(ref.watch(dropboxAuthProvider.notifier)),
);
