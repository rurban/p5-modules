#!/usr/bin/perl

use strict;
use warnings;

use Test::More no_plan => 1;
use Test::Exception;

use_ok('Perl6::Core::Closure');
use_ok('Perl6::Core::Hash');
use_ok('Perl6::Core::Num');

my $top_level_env = closure::env->new();
isa_ok($top_level_env, 'closure::env');

$top_level_env->create('$foo' => num->new(10));

=pod

my $foo = 10;

sub dynamic_accessor ($num = 50) {
    return [ $foo, $num ];
}

=cut

{

    my $closure = closure->new(
        $top_level_env, 
        closure::signature->new(
            params  => closure::params->new(symbol->new('$num')),
            returns => 'list'
        ),
        sub { 
            my $e = shift;
            return list->new($e->get('$num'), $e->get('$foo'));
        }
    );

    {
        my $results = $closure->do(list->new(num->new(100)));
        isa_ok($results, 'list');

        isa_ok($results->fetch(num->new(0)), 'num');
        cmp_ok($results->fetch(num->new(0))->to_native, '==', 100, '... got one of the expected values');
    
        isa_ok($results->fetch(num->new(1)), 'num');
        cmp_ok($results->fetch(num->new(1))->to_native, '==', 10, '... got one of the expected values');
    }

    $top_level_env->set('$foo' => num->new(35));

    {
        my $results = $closure->do();
        isa_ok($results, 'list');

        isa_ok($results->fetch(num->new(0)), 'nil');

        isa_ok($results->fetch(num->new(1)), 'num');
        cmp_ok($results->fetch(num->new(1))->to_native, '==', 35, '... got one of the expected values');
    }


}

=pod

sub create_counter {
    my $counter = 0;
    return sub {
        $counter++;
    }
}

=cut

{

    my $closure = closure->new(
        $top_level_env, 
        closure::signature->new(
            params  => closure::params->new(),
            returns => 'closure'
        ), 
        sub { 
            my $e = shift;
            $e->create('$counter' => num->new(0));
            return closure->new($e, closure::params->new(), sub {
                my $e = shift;
                $e->set('$counter' => $e->get('$counter')->increment);
                $e->get('$counter');
            });
        }
    );

    {
        my $inner = $closure->do();
        isa_ok($inner, 'closure');

        {
            my $result = $inner->do();
            isa_ok($result, 'num');            
            cmp_ok($result->to_native, '==', 1, '... got the right inc value');
        }
        
        {
            my $result = $inner->do();
            isa_ok($result, 'num');            
            cmp_ok($result->to_native, '==', 2, '... got the right inc value');
        }        
        
        {
            my $result = $inner->do();
            isa_ok($result, 'num');            
            cmp_ok($result->to_native, '==', 3, '... got the right inc value');
        }        
    }    
    
}

# type checking the params

{

    my $closure = closure->new(
        $top_level_env, 
        closure::params->new(symbol->new('$num' => 'num')), 
        sub { 
            my $e = shift;
            return $e->get('$num')
        }
    );

    my $val;
    lives_ok {
        $val = $closure->do(list->new(num->new(100)));
    } '... we passed a correctly typed value';
    isa_ok($val, 'num');
    is($val->to_native, 100, '... our value is 100');

    dies_ok {
        $closure->do(list->new(str->new('FAIL')));
    } '... we passed the wrong type value';
    
    dies_ok {
        $closure->do(list->new());
    } '... we passed the no value';    
    
    dies_ok {
        $closure->do(list->new(num->new(10), num->new(100)));
    } '... we passed in too many values';        

}

# using 'type' to allow anything 

{

    my $closure = closure->new(
        $top_level_env, 
        closure::params->new(symbol->new('$num' => 'type')), 
        sub { 
            my $e = shift;
            return $e->get('$num')
        }
    );

    lives_ok {
        $closure->do(list->new(num->new(100)));
    } '... we passed a any typed value';
    
    lives_ok {
        $closure->do(list->new(str->new('hello world')));
    } '... we passed a any typed value';    
    
    lives_ok {
        $closure->do(list->new());
    } '... we passed a any typed value';    
    
    dies_ok {
        $closure->do(list->new(num->new(10), num->new(100)));
    } '... we passed in too many values';        

}

# type checking the return type

{

    my $closure = closure->new(
        $top_level_env, 
        closure::signature->new(
            params  => closure::params->new(symbol->new('$x' => 'type')),
            returns => 'str'
        ), 
        sub { (shift)->get('$x') }
    );

    my $val;
    lives_ok {
        $val = $closure->do(list->new(str->new('hello world')));
    } '... we got back a correctly typed value';
    isa_ok($val, 'str');
    is($val->to_native, 'hello world', '... our value is "hello world"');

    dies_ok {
        $closure->do(list->new(num->new(1)));
    } '... we returned the wrong type value';

    lives_ok {
        $closure->do(list->new());
    } '... we passed in no value (and so returned nil)';    

}

# type checking the return type

{

    my $closure = closure->new(
        $top_level_env, 
        closure::signature->new(
            params => closure::params->new(symbol->new('$x' => 'type')),
        ), 
        sub { (shift)->get('$x') }
    );

    {
        my $val;
        lives_ok {
            $val = $closure->do(list->new(str->new('hello world')));
        } '... we got back a correctly typed value';
        isa_ok($val, 'str');
        is($val->to_native, 'hello world', '... our value is "hello world"');
    }   
    
    {
        my $val;
        lives_ok {
            $val = $closure->do(list->new(num->new(100)));
        } '... we got back a correctly typed value';
        isa_ok($val, 'num');
        is($val->to_native, 100, '... our value is 100');        
    }
    
    {
        my $val;
        lives_ok {
            $val = $closure->do(list->new());
        } '... we got back a correctly typed value';
        isa_ok($val, 'nil');
    }    
}



