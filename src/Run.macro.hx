import haxe.macro.*;

function afterBuild() {
  Context.onAfterGenerate(() -> {
    switch Sys.command('node', [Compiler.getOutput()]) {
      case 0:
      case v: Context.error('Exited with code $v', Context.currentPos());
    }
  });
}