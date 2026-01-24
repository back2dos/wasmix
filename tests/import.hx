#if js
  #if nodejs
    import js.Node.console;
  #else
    import js.Browser.console;
  #end
#end

#if macro
  import haxe.macro.*;

  using haxe.macro.Tools;
#end