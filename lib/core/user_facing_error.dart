import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// Turns a failure from a remote catalog into one sentence a reader can act
/// on. Exception text (`DioException [receive timeout]: …`) belongs in the
/// log, not on screen.
String userFacingErrorMessage(BuildContext context, Object error) {
  if (_isConnectionFailure(error)) {
    return context.tr(
      '无法连接服务器，请检查网络后重试。',
      "Couldn't connect. Check your connection and try again.",
      '接続できませんでした。接続を確認して再試行してください。',
    );
  }
  if (_isTimeout(error)) {
    return context.tr(
      '服务器响应太慢，请稍后重试。',
      'The server is taking too long to respond. Try again in a moment.',
      'サーバーの応答に時間がかかっています。しばらくしてから再試行してください。',
    );
  }
  if (error is DioException && error.type == DioExceptionType.badResponse) {
    return context.tr(
      '服务暂时不可用，请稍后重试。',
      'This service is unavailable right now. Try again later.',
      'このサービスは現在利用できません。後でもう一度お試しください。',
    );
  }
  return context.tr(
    '加载失败，请重试。',
    'Something went wrong while loading. Try again.',
    '読み込みに失敗しました。再試行してください。',
  );
}

bool _isTimeout(Object error) =>
    error is TimeoutException ||
    (error is DioException &&
        (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout));

bool _isConnectionFailure(Object error) =>
    error is SocketException ||
    error is TlsException ||
    (error is DioException &&
        (error.type == DioExceptionType.connectionError ||
            error.error is SocketException ||
            error.error is TlsException));
