sub JS::Root::substr(Str $str, Int $a, Int ?$b = chars $str) is primitive {
  JS::inline('function (str, a, b) {
    return String(str).substr(Number(a), Number(b));
  }')(~$str, +$a, +$b < 0 ?? +$b + chars $str :: +$b);
}

method split(Str $self: Str $splitter) { split $splitter, $self }
sub JS::Root::split(Str $splitter, Str $str) is primitive {
  JS::inline('
    function (splitter, str) {
      return String(str).split(String(splitter));
    }
  ')(~$splitter, ~$str);
}

method uc(Str $self:) { JS::inline('function (str) { return str.toUpperCase() }')(~$self) }
method lc(Str $self:) { JS::inline('function (str) { return str.toLowerCase() }')(~$self) }

method lcfirst(Str $self:) { lc(substr $self, 0, 1) ~ substr($self, 1) }
method ucfirst(Str $self:) { uc(substr $self, 0, 1) ~ substr($self, 1) }

method chars(Str $self:) { JS::inline('function (str) { return str.length }')(~$self) }

method index(Str $self: Str $substr, Int ?$pos = 0) {
  JS::inline('function (str, substr, pos) {
    return str.indexOf(substr, pos);
  }')(~$self, ~$substr, +$pos);
}
method rindex(Str $self: Str $substr, Int ?$pos = chars $self) {
  if $self eq "" and $substr ne "" {
    -1;
  } else {
    JS::inline('function (str, substr, pos) {
      return str.lastIndexOf(substr, pos);
    }')(~$self, ~$substr, +$pos);
  }
}

method chomp(Str $self:) {
  if substr($self, -1, 1) eq "\n" {
    substr $self, 0, -1;
  } else {
    ~$self;
  }
}
