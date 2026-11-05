import 'package:fluttertoast/fluttertoast.dart';

class AppToast {
  AppToast._();

  static void show(String message, {bool long = false}) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: long ? Toast.LENGTH_LONG : Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: long ? 3 : 2,
    );
  }
}
