#if travix
import travix.Logger.*;
#elseif sys
import Sys.*;
#else
#error
#end
class Assert {
  static var total = 0;
  static var passed = 0;
  static var suite = null;
  static var subsuite = null;

  static function _assert(holds:Bool, message:String, module:String, method:String) {
    total++;
    if (suite != module) {
      println('\nTesting ${suite = module}:\n');
      subsuite = null;
    }

    if (method != subsuite) {
      subsuite = switch method {
        case 'main': null;
        case v: 
          println('\n  $v:\n');
          v;
      }
    }
    var indent = subsuite == null ? '  ' : '    ';
    if (holds) {
      println('$indent[✔] - $message');
      passed++;
    } else {
      println('$indent[✘] - $message');
    }
  }



  static public macro function that();
  static public function report() {
    println('\n${passed} / ${total} assertions passed');
    exit(total == passed ? 0 : 1);
  }
}