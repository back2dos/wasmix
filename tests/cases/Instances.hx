package cases;

import wasmix.Compile;
import wasmix.runtime.*;

function main() {
  final game = Compile.module(GameLogic);

  game.testPointCreation();
  game.testPointFieldAccess();
  game.testPointFieldMutation();
  game.testPointMethods();
  game.testCounterOperations();
  game.testRectangleOperations();
  game.testChainedOperations();
}

// External classes that will be instantiated from WASM

class Point {
  public var x:Int;
  public var y:Int;

  public function new(x:Int, y:Int) {
    this.x = x;
    this.y = y;
  }

  public function distanceSquared(other:Point):Int {
    final dx = x - other.x;
    final dy = y - other.y;
    return dx * dx + dy * dy;
  }

  public function translate(dx:Int, dy:Int):Void {
    x += dx;
    y += dy;
  }

  public function clone():Point {
    return new Point(x, y);
  }

  public function dot(other:Point):Int {
    return x * other.x + y * other.y;
  }

  public function toString():String {
    return 'Point($x, $y)';
  }
}

class Counter {
  public var value:Int;
  public var step:Int;

  public function new(initial:Int, step:Int) {
    this.value = initial;
    this.step = step;
  }

  public function increment():Int {
    value += step;
    return value;
  }

  public function decrement():Int {
    value -= step;
    return value;
  }

  public function reset():Void {
    value = 0;
  }
}

class Rectangle {
  public var x:Int;
  public var y:Int;
  public var width:Int;
  public var height:Int;

  public function new(x:Int, y:Int, width:Int, height:Int) {
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
  }

  public function area():Int {
    return width * height;
  }

  public function contains(px:Int, py:Int):Bool {
    return px >= x && px < x + width && py >= y && py < y + height;
  }

  public function topLeft():Point {
    return new Point(x, y);
  }

  public function bottomRight():Point {
    return new Point(x + width, y + height);
  }
}

// This class gets compiled to WASM
class GameLogic {
  // Test creating instances
  static public function testPointCreation() {
    final p = new Point(10, 20);
    // Verify creation by accessing fields
    Assert.that(p.x == 10);
    Assert.that(p.y == 20);
  }

  // Test reading instance fields
  static public function testPointFieldAccess() {
    final p = new Point(5, 15);
    Assert.that(p.x == 5);
    Assert.that(p.y == 15);
  }

  // Test writing/mutating instance fields
  static public function testPointFieldMutation() {
    final p = new Point(0, 0);

    // Simple assignment
    p.x = 10;
    Assert.that(p.x == 10);

    // Compound assignment
    p.x += 5;
    Assert.that(p.x == 15);

    p.y = 20;
    p.y -= 8;
    Assert.that(p.y == 12);

    // Increment/decrement
    p.x++;
    Assert.that(p.x == 16);

    ++p.x;
    Assert.that(p.x == 17);

    p.y--;
    Assert.that(p.y == 11);

    --p.y;
    Assert.that(p.y == 10);

    // Multiply/divide assignments
    p.x *= 2;
    Assert.that(p.x == 34);

    p.y <<= 1;
    Assert.that(p.y == 20);
  }

  // Test calling instance methods
  static public function testPointMethods() {
    final p1 = new Point(0, 0);
    final p2 = new Point(3, 4);

    // Method call returning value
    final distSq = p1.distanceSquared(p2);
    Assert.that(distSq == 25); // 3^2 + 4^2 = 9 + 16 = 25

    // Method call with void return
    p1.translate(5, 5);
    Assert.that(p1.x == 5);
    Assert.that(p1.y == 5);

    // Method returning new instance
    final p3 = p2.clone();
    Assert.that(p3.x == 3);
    Assert.that(p3.y == 4);

    // Dot product
    final dot = p1.dot(p2);
    Assert.that(dot == 35); // 5*3 + 5*4 = 15 + 20 = 35
  }

  // Test Counter operations with multiple fields
  static public function testCounterOperations() {
    final counter = new Counter(0, 5);

    Assert.that(counter.value == 0);
    Assert.that(counter.step == 5);

    Assert.that(counter.increment() == 5);
    Assert.that(counter.value == 5);

    Assert.that(counter.increment() == 10);
    Assert.that(counter.increment() == 15);

    Assert.that(counter.decrement() == 10);

    counter.reset();
    Assert.that(counter.value == 0);

    // Modify step
    counter.step = 10;
    Assert.that(counter.increment() == 10);
    Assert.that(counter.increment() == 20);
  }

  // Test Rectangle with methods returning new instances
  static public function testRectangleOperations() {
    final rect = new Rectangle(10, 20, 100, 50);

    Assert.that(rect.area() == 5000);

    Assert.that(rect.contains(50, 30) == true);
    Assert.that(rect.contains(5, 30) == false);  // left of rect
    Assert.that(rect.contains(150, 30) == false); // right of rect

    final tl = rect.topLeft();
    Assert.that(tl.x == 10);
    Assert.that(tl.y == 20);

    final br = rect.bottomRight();
    Assert.that(br.x == 110);
    Assert.that(br.y == 70);
  }

  // Test chained operations
  static public function testChainedOperations() {
    // Create and immediately access
    Assert.that(new Point(7, 8).x == 7);
    Assert.that(new Point(7, 8).y == 8);

    // Create and call method
    Assert.that(new Rectangle(0, 0, 10, 10).area() == 100);

    // Method result field access
    final rect = new Rectangle(5, 5, 20, 30);
    Assert.that(rect.topLeft().x == 5);
    Assert.that(rect.bottomRight().y == 35);

    // Clone and modify
    final original = new Point(100, 200);
    final copy = original.clone();
    copy.x = 999;
    Assert.that(original.x == 100); // original unchanged
    Assert.that(copy.x == 999);
  }
}
