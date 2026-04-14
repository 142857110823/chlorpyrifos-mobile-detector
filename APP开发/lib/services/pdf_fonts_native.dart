/// PDF字体原生实现 - 非Web平台
import 'package:printing/printing.dart' as printing;

class PdfGoogleFonts {
  static Future<dynamic> notoSansSCRegular() => printing.PdfGoogleFonts.notoSansSCRegular();
  static Future<dynamic> notoSansSCBold() => printing.PdfGoogleFonts.notoSansSCBold();
}
