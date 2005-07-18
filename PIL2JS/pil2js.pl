#!/usr/bin/perl
# This is the frontend for the modules PIL::Parser and PIL::Nodes.
# See sub &usage at the bottom for usage information.

use warnings;
use strict;
use lib "lib";

use Getopt::Long;
use PIL::Parser;
use PIL::Nodes;

GetOptions(
  "verbose"      => \my $verbose,
  "html"         => \my $html,
  "no-jsprelude" => \my $no_jsprelude,
  "preludepc=s"  => \my $preludepc,
  "yaml-dump"    => \my $yaml_dump,
  "help"         => \&usage,
) or usage();

die "Option --preludepc needs --html.\n"
  if $preludepc and not $html;
die <<ERR if $yaml_dump and ($html or $no_jsprelude or $preludepc);
Option --yaml-dump only dumps the PIL parse tree as YAML and then
exits; Terefore, it can't be used in conjunction with --html,
--no-jsprelude, or --preludepc.
ERR

local $/;
my $pil  = <>;
my $tree = PIL::Parser->parse($pil);

if($yaml_dump) {
  require YAML;
  print YAML::Dump($tree);
  exit;
}

# This is the part of the JS Prelude which needs to be written in JS.
local $_;
my $prelude = <<'EOF';
if(PIL2JS == undefined) var PIL2JS = {};

// This is necessary to emulate pass by ref, needed for is rw and is ref.
PIL2JS.Box = function (value) {
  this.GET   = function ()  { return value };
  this.STORE = function (n) { value = n.GET(); return n };
};

PIL2JS.Box.prototype = {
  clone: function () {
    return new PIL2JS.Box(this.GET());
  },
  toNative: function () {
    var unboxed = this.GET();
    if(unboxed instanceof Array) {
      var arr = [];
      for(var i = 0; i < unboxed.length; i++) {
        arr.push(unboxed[i].toNative());
      }
      return arr;
    } else if(unboxed instanceof Function) {
      return function () {
        var args = arguments;
        for(var i = 0; i < args.length; i++)
          args[i] = new PIL2JS.Box.Constant(args[i]);
        return unboxed(args).toNative();
      };
    } else {
      return unboxed;
    }
  },
  perl_methods: {}
  /*
    toString: function () {
      _26main_3a_3aprefix_3a_7e.GET()([this]);
    },
  */
};

PIL2JS.Box.ReadOnly = function (box) {
  this.GET   = function ()  { return box.GET() };
  this.STORE = function (n) { PIL2JS.die("Can't modify constant item!\n"); return n };
};
PIL2JS.Box.Constant = function (value) {
  this.GET   = function ()  { return value };
  this.STORE = function (n) { PIL2JS.die("Can't modify constant item!\n"); return n };
};
PIL2JS.Box.Stub = function (value) {
  this.GET   = function ()  { PIL2JS.die(".GET() of a PIL2JS.Box.Stub called!\n") }
  this.STORE = function (n) { PIL2JS.die(".STORE() of a PIL2JS.Box.Stub called!\n"); return n };
};

PIL2JS.Box.ReadOnly.prototype = PIL2JS.Box.prototype;
PIL2JS.Box.Constant.prototype = PIL2JS.Box.prototype;
PIL2JS.Box.Stub.prototype     = PIL2JS.Box.prototype;

// Call (possibly native sub) sub with args
PIL2JS.call = function (inv, sub, args) {
  if(sub == undefined)
    PIL2JS.die("Use of uninitialized value in subroutine entry!\n");

  // It's a plain sub (i.e. not method) call.
  if(inv == undefined) {
    // It's a boxed (and therefore Perl 6) sub.
    if(sub.GET) {
      return sub.GET()(args);
    } else {
      var code = "new PIL2JS.Box.Constant(sub(";
      for(var i = 0; i < args.length; i++) {
        code += "args[" + i + "].toNative(),";
      }
      if(code.substr(-1, 1) == ",") code = code.slice(0, -1);
      code += "))";
      return eval(code);
    }
  } else {
    if(inv.GET) {
      if(inv.perl_methods[sub]) {
        return inv.perl_methods[sub].GET()([inv].concat(args));
      } else {
        PIL2JS.die("No such method: \"" + sub + "\"");
      }
    } else {
      PIL2JS.die("Internal error: PIL2JS.call not implemented for invocation of native methods\n");
    }
  }
};

PIL2JS.make_slurpy_array = function (inp_arr) {
  var out_arr = [];

  for(var i = 0; i < inp_arr.length; i++) {
    if(inp_arr[i].GET() instanceof Array) {
      out_arr = out_arr.concat(inp_arr[i].GET());
    } else {
      out_arr.push(inp_arr[i]);
    }
  }

  return out_arr;
};

_24main_3a_3a_3fPOSITION = new PIL2JS.Box("<unknown>");

PIL2JS.die = function (msg) {
  var error = new Error(msg.substr(-1, 1) == "\n"
    ? msg
    : msg + " at " + _24main_3a_3a_3fPOSITION.toNative()
  );
  alert(error);
  throw(error);
};

PIL2JS.Exception = {};
PIL2JS.Exception.last = function () {}
EOF

my $js = join "\n", map { $_->as_js } @{ $tree->{"pilGlob"} }, $tree->{pilMain};

unless($html) {
  print $prelude . "\n" unless $no_jsprelude;
  print $js;
} else {
  # Output a standard HTML skeleton.
  my $indent = sub { join "\n", map { " " x 6 . $_ } split "\n", shift };
  printf <<EOF, $no_jsprelude ? "" : $indent->($prelude), $indent->($js);
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>PIL2JS</title>
  </head>

  <body>
    <pre id="__pil2js_tty"></pre>

    @{[
      $no_jsprelude
        ? ""
        : "<script type=\"text/javascript\">//<![CDATA[\n%s\n    //]]</script>\n"
    ]}
    @{[
      $preludepc
        ? "<script type=\"text/javascript\" src=\"$preludepc\"></script>\n"
        : ""
    ]}
    <script type="text/javascript">//<![CDATA[
%s
      //]]
    </script>
  </body>
</html>
EOF
}

sub usage { print STDERR <<USAGE; exit }
pil2js.pl compiles PIL code given in STDIN to JavaScript code, outputted to
STDOUT.

Available options (options may be abbreviated to uniqueness):
  --verbose           Sets verboseness.
  --html              Outputs the JavaScript packed in an HTML page.
  --no-jsprelude      Omits the part of the Prelude written in JavaScript.
  --preludepc=http://.../preludepc.js
                      Sets the path to a precompiled Prelude.

Recommended usage:
  \$ cd perl5/PIL2JS
  \$ pugs -CPIL -Ilib6 -MPrelude::JS -we 'say 2 + 3' | \
    ./pil2js.pl --html > test.js
  # or (*much* faster)
  \$ pugs -CPIL -Ilib6 -MPrelude::JS -we '' | \
    ./pil2js.pl --no-jsprelude > preludepc.js
  \$ pugs -CPIL -we 'say 2 + 3' | \
    ./pil2js.pl --html --preludepc="http://.../preludepc.js" > test.js

USAGE
