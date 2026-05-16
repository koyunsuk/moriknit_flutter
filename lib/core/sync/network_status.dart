// 이슈 #704 Phase 1 — 네트워크 상태 감지 서비스.
//
// connectivity_plus 기반으로 online/offline 상태를 스트림으로 제공.
// Riverpod StreamProvider로 노출되어 어떤 위젯에서든 watch 가능.
//
// 사용:
// ```dart
// final status = ref.watch(networkStatusProvider);
// status.when(
//   data: (s) => s == NetworkStatus.online ? ... : ...,
//   loading: () => ...,
//   error: (_, __) => ...,
// );
// ```

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 네트워크 연결 상태.
enum NetworkStatus { online, offline, unknown }

/// 네트워크 상태 감지 서비스.
/// 시작 후 connectivity_plus의 onConnectivityChanged를 구독하여
/// 상태 변화 시 broadcast 스트림으로 emit.
class NetworkStatusService {
  final Connectivity _connectivity = Connectivity();
  StreamController<NetworkStatus>? _controller;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  NetworkStatus _current = NetworkStatus.unknown;
  bool _started = false;

  /// 현재 상태 스트림 (broadcast).
  Stream<NetworkStatus> get stream {
    _controller ??= StreamController<NetworkStatus>.broadcast();
    return _controller!.stream;
  }

  /// 마지막으로 관측된 상태.
  NetworkStatus get current => _current;

  /// 편의 게터: 온라인 여부.
  bool get isOnline => _current == NetworkStatus.online;

  /// 편의 게터: 오프라인 여부.
  bool get isOffline => _current == NetworkStatus.offline;

  /// 감지 시작. 멱등(여러 번 호출해도 1회만 동작).
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _controller ??= StreamController<NetworkStatus>.broadcast();

    try {
      final initial = await _connectivity.checkConnectivity();
      _emit(_fromList(initial));
    } catch (_) {
      // 초기 체크 실패 시 unknown 유지.
    }

    _sub = _connectivity.onConnectivityChanged.listen(
      (list) => _emit(_fromList(list)),
      onError: (_) {
        // 스트림 에러는 무시 (상태 미변경).
      },
    );
  }

  NetworkStatus _fromList(List<ConnectivityResult> list) {
    if (list.isEmpty) return NetworkStatus.offline;
    if (list.every((r) => r == ConnectivityResult.none)) {
      return NetworkStatus.offline;
    }
    return NetworkStatus.online;
  }

  void _emit(NetworkStatus s) {
    if (s == _current) return;
    _current = s;
    _controller?.add(s);
  }

  /// 자원 해제.
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _controller?.close();
    _controller = null;
    _started = false;
  }
}

/// 글로벌 NetworkStatusService 인스턴스 Provider.
/// 앱 라이프사이클 동안 단일 인스턴스 공유.
final networkStatusServiceProvider = Provider<NetworkStatusService>((ref) {
  final svc = NetworkStatusService();
  // 웹에서도 connectivity_plus가 동작하지만 일부 브라우저에서 제한적.
  // start는 안전하게 항상 호출 (실패 시 unknown 유지).
  // ignore: discarded_futures
  svc.start();
  ref.onDispose(() {
    // ignore: discarded_futures
    svc.dispose();
  });
  return svc;
});

/// 네트워크 상태 변화 스트림 Provider.
final networkStatusProvider = StreamProvider<NetworkStatus>((ref) {
  final svc = ref.watch(networkStatusServiceProvider);
  // 초기값을 즉시 yield 하기 위해 현재 값을 prepend.
  // (현재값은 unknown일 수 있음 — 스트림이 곧 실제 값을 emit)
  return _yieldCurrentThen(svc);
});

Stream<NetworkStatus> _yieldCurrentThen(NetworkStatusService svc) async* {
  yield svc.current;
  yield* svc.stream;
}

/// 편의 Provider: 현재 온라인 여부 (bool).
final isOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(networkStatusProvider).asData?.value;
  // unknown 상태는 일단 online으로 간주 (낙관적 동작).
  // kIsWeb에서 초기 unknown은 흔함.
  if (status == null) return !kIsWeb;
  return status == NetworkStatus.online || status == NetworkStatus.unknown;
});
