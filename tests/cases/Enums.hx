package cases;

import wasmix.Compile;

function main() {
  final enums = Compile.module(Enums);

  enums.basicEnums();
  enums.enumsWithArgs();
  enums.nestedEnums();
  enums.patternMatching();
}

// Simple enum without arguments
enum Priority {
  Low;
  Medium;
  High;
  Critical;
}

// Enum with arguments
enum Result {
  Ok(value:Int);
  Error(code:Int, message:String);
}

// Enum containing another enum
enum Task {
  Pending(priority:Priority);
  InProgress(priority:Priority, assignee:String);
  Completed(result:Result);
  Cancelled(reason:String);
}

class Enums {

  static public function basicEnums() {
    final p1 = Low;
    final p2 = High;
    
    Assert.that(p1.equals(Low));
    Assert.that(!p2.equals(Low));
    Assert.that(!p1.equals(p2));
  }

  static public function enumsWithArgs() {
    final ok = Ok(42);
    final err = Error(404, "Not found");

    // Check enum matching
    switch ok {
      case Ok(v): Assert.that(v == 42);
      case Error(_, _): Assert.that(false);
    }

    switch err {
      case Ok(_): Assert.that(false);
      case Error(code, msg): 
        Assert.that(code == 404);
        Assert.that(msg == "Not found");
    }
  }

  static public function nestedEnums() {
    final pending = Pending(High);
    final inProgress = InProgress(Critical, "Alice");
    final completed = Completed(Ok(100));
    final failed = Completed(Error(500, "Timeout"));

    // Extract nested priority
    switch pending {
      case Pending(p): Assert.that(p.equals(High));
      default: Assert.that(false);
    }

    // Extract nested enum with arguments
    switch inProgress {
      case InProgress(p, who):
        Assert.that(p.equals(Critical));
        Assert.that(who == "Alice");
      default: Assert.that(false);
    }

    Assert.that(completed.match(Completed(Ok(100))));
    Assert.that(completed.equals(Completed(Ok(100))));

    Assert.that(failed.match(Completed(Error(500, _))));
    Assert.that(failed.equals(Completed(Error(500, "Timeout"))));
  }

  static public function patternMatching() {
    // Test helper function that uses pattern matching
    Assert.that(priorityValue(Low) == 1);
    Assert.that(priorityValue(Medium) == 2);
    Assert.that(priorityValue(High) == 3);
    Assert.that(priorityValue(Critical) == 4);

    // Test task status description
    Assert.that(isUrgent(Pending(Low)) == false);
    Assert.that(isUrgent(Pending(Critical)) == true);
    Assert.that(isUrgent(InProgress(High, "Bob")) == true);
    Assert.that(isUrgent(Completed(Ok(0))) == false);
  }

  static public function priorityValue(p:Priority):Int {
    return switch p {
      case Low: 1;
      case Medium: 2;
      case High: 3;
      case Critical: 4;
    }
  }

  static function isUrgent(task:Task):Bool {
    return switch task {
      case Pending(Critical) | InProgress(Critical, _): true;
      case Pending(High) | InProgress(High, _): true;
      case _: false;
    }
  }
}
