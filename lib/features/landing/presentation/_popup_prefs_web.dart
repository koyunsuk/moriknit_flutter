import 'package:web/web.dart' as web;

String? getPopupDismissed() => web.window.localStorage.getItem('_mori_feat_popup');
void setPopupDismissed(String date) => web.window.localStorage.setItem('_mori_feat_popup', date);
