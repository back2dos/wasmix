package cases;

import wasmix.Compile;
import wasmix.runtime.*;

function main() {
  final physics = Compile.module(Physics, { sync: true });
  
  // Test reading external static field
  Assert.that(physics.getGravity() == 10);
  
  // Test reading own static field  
  Assert.that(physics.getDefaultMass() == 1);
  
  // Test calling external static method
  Assert.that(physics.clampedSpeed(150) == 100);
  Assert.that(physics.clampedSpeed(50) == 50);
  
  // Test calling own static method from another
  Assert.that(physics.fallingSpeed(0) == 0);
  Assert.that(physics.fallingSpeed(1) == 10);  // gravity * time
  Assert.that(physics.fallingSpeed(2) == 20);
  
  // Test combining external field + own method + external method
  final energy = physics.kineticEnergy(4);  // 0.5 * mass * velocity^2 = 0.5 * 1 * 16 = 8
  Assert.that(energy == 8);
}

// External constants and utilities (not wasmixed)
class Config {
  public static var GRAVITY:Int = 10;
  public static var MAX_SPEED:Int = 100;
  
  public static function clamp(value:Int, min:Int, max:Int):Int {
    return if (value < min) min else if (value > max) max else value;
  }
}

// This class gets compiled to WASM
class Physics {
  // Own static constant
  static var DEFAULT_MASS:Int = 1;
  
  // Read external static field
  static public function getGravity():Int {
    return Config.GRAVITY;
  }
  
  // Read own static field
  static public function getDefaultMass():Int {
    return DEFAULT_MASS;
  }
  
  // Call external static method
  static public function clampedSpeed(speed:Int):Int {
    return Config.clamp(speed, 0, Config.MAX_SPEED);
  }
  
  // Call own static method
  static public function fallingSpeed(seconds:Int):Int {
    return getGravity() * seconds;
  }
  
  // Combine: external field + own method
  static public function kineticEnergy(velocity:Int):Int {
    // KE = 0.5 * m * v^2, using integer math: (m * v * v) >> 1
    final mass = getDefaultMass();
    return (mass * velocity * velocity) >> 1;
  }
}
