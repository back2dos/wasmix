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
  static function _assert(holds:Bool, message:String, module:String) {
    total++;
    if (suite != module) 
      println('\nTesting ${suite = module}:\n');
    if (holds) {
      println('  [✔] - ${message}');
      passed++;
    } else {
      println('  [✘] - ${message}');
    }
  }



  static public macro function that();
  static public function report() {
    println('\n${passed} / ${total} assertions passed');
    exit(total == passed ? 0 : 1);
  }
}