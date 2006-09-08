
use v6-alpha;

# Perl6 implementation of the 'Rule' syntax 
# author: Flavio S. Glock - fglock@gmail.com

=for compiling

    After compiling:
    - remove all references to:
        Data::Bind
    - replace the header with:
        package Pugs::Grammar::Rule;
        no strict 'refs';
        use Pugs::Runtime::Match;
        use Pugs::Emitter::Rule::Perl5::Ratchet;
        our %rule_terms;

=cut

grammar Pugs::Grammar::Rule;

#use Pugs::Runtime::Match;

our %rule_terms;

token pod_begin {
    |   \n =end \N*
    |   . \N* <?pod_begin>
}

token pod_other {
    |   \n =cut \N*
    |   . \N* <?pod_other>
}

token ws {
    [
    |    \# \N*
    |    \n [ = [
            |  begin <?ws> END \N* .*
            |  begin  <?pod_begin>
            |  kwid   <?pod_other>
            |  pod    <?pod_other>
            |  for    <?pod_other>
            |  head1  <?pod_other>
            ]?
            ]?
    |    \s
    ]+
}

# regex ident can start with a number
token ident {
    [ <?alnum> | _ | <'::'> ]+
}

token capturing_group {
    \( <rule> \)
    { return { capturing_group => $/{'rule'}() ,} }
}

token non_capturing_group {
    \[ <rule> \] 
    { return $/{'rule'}() }
}

token literal {
    [ 
    |  \\ .
    |  <-[ \' ]> 
    ]*
}

token metasyntax {
    [ 
    |  \\ .
    |  \'  <?literal>     \'
    |  \{  <?code>        \}
    |  \<  <?metasyntax>  \>
    |  <-[ \> ]> 
    ]+ 
    { return { metasyntax => $/() ,} }
}

token code {
    # bootstrap code
    [ 
    |  \\ .
    |  \'  <?literal>     \'
    |  \{  <?code>        \}
    |  <-[ \} ]> 
    ]+ 
}

token named_capture_body {
    | <capturing_group>     { return { rule => $/{'capturing_group'}(), } } 
    | <non_capturing_group> { return { rule => $/{'non_capturing_group'}(),} } 
    | \<  <metasyntax>  \>  { return { rule => $/{'metasyntax'}(), } } 
    | { die "invalid alias syntax" }
}

%rule_terms = (

    '(' => token {
        <rule> \)
        { return { capturing_group => $/{'rule'}() ,} }
    },
    '<after' => token {
        <?ws> <rule> \> 
        { return { after => {
                rule  => $/{'rule'}(),
            }, } 
        }
    },
    '<before' => token {
        <?ws> <rule> \> 
        { return { before => {
                rule  => $/{'rule'}(),
            }, } 
        }
    },
    '<!before' => token {
        <?ws> <rule> \> 
        { return { not_before => {
                rule  => $/{'rule'}(),
            }, } 
        }
    },
    '<!' => token {
        <rule> \> 
        { return { negate => {
                rule  => $/{'rule'}(),
            }, } 
        }
    },
    '<' => token { 
        <metasyntax>  \>
        { return $/{'metasyntax'}() }
    },
    '$<' => token {
        <ident> \> <?ws>? <':='> <?ws>? <named_capture_body>
        { 
            use v5;
            my $body = $/{'named_capture_body'}();
            $body->{'ident'} = $/{'ident'}();
            return { named_capture => $body, }; 
            use v6;
        }
    },
    '$' => token { 
        <?digit>+
        { return { match_variable => '$' ~ $/() ,} }
    |
        \^?
        [ <?alnum> | _ | \: \: ]+
        { return { variable => '$' ~ $() ,} }
    |
        { return { colon => '$'  ,} }
    },
    '@' => token { 
        <?digit>+
        { return { match_variable => '@' ~ $/() ,} }
    |
        \^?
        [ <?alnum> | _ | \: \: ]+
        { return { variable => '@' ~ $() ,} }
    },
    '%' => token { 
        <?digit>+
        { return { match_variable => '%' ~ $/() ,} }
    |
        \^?
        [ <?alnum> | _ | \: \: ]+
        { return { variable => '%' ~ $() ,} }
    },
    '{' => token { 
        <code>  \}
        { return { closure => $/{'code'}() ,} }
    },
    '\\' => token {  
        .
        { return { special_char => '\\' ~ $(), } } 
    },
    '.' => token { 
        { return { 'dot' => 1 ,} }
    },
    '[' => token { 
        <rule> \] 
        { return $/{'rule'}() }
    },
    ':::' => token { { return { colon => ':::' ,} } },
    ':?'  => token { { return { colon => ':?' ,} } },
    ':+'  => token { { return { colon => ':+' ,} } },
    '::'  => token { { return { colon => '::' ,} } },
    ':'   => token { { return { colon => ':'  ,} } },
    '$$'  => token { { return { colon => '$$' ,} } },
    '^^'  => token { { return { colon => '^^' ,} } },
    '^'   => token { { return { colon => '^'  ,} } },
); # /%rule_terms
    
token term {
    |  <%Pugs::Grammar::Rule::rule_terms>
        { 
            #print "term: ", Dumper( $_[0]->data );
            return $/{'Pugs::Grammar::Rule::rule_terms'}() 
        }
    |  <-[ \] \} \) \> \: \? \+ \* \| \& ]> 
        { 
            #print "constant: ", Dumper( $_[0]->data );
            return { 'constant' => $() ,} 
        }
}

token quantifier {
    $<ws1>   := (<?ws>?)
    <!before  <[   \} \] \) \>   ]> >
    <term> 
    $<ws2>   := (<?ws>?)
    $<quant> := (
        <[  \? \* \+  ]>?
        <'?'>?
    )
    $<ws3>   := (<?ws>?)
    { return { 
        quant => { 
            term  => $/{'term'}(),
            quant => $/{'quant'}(),
            ws1   => $/{'ws1'}(),
            ws2   => $/{'ws2'}(),
            ws3   => $/{'ws3'}(),
        } }
    }
}

token concat {
    <quantifier>+ 
    {             
      use v5;
        my @a = map {  $_->()  }  @{ $::_V6_MATCH_->{'quantifier'} };
        return { concat => \@a ,}  if scalar @a > 1;
        return $a[0];
      use v6;
    }
}

token rule {
    [ <?ws>? \| ]?
    
    <concat>
    [
        \|  <concat> 
    ]*
    
    {             
      use v5;
        my @a = map {  $_->()  }  @{ $::_V6_MATCH_->{'concat'} };
        return { alt => \@a ,}  if scalar @a > 1;
        return $a[0];
      use v6;
    }
}
