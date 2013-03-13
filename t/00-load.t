#!perl -T

use Test::More tests => 2;

BEGIN {
    use_ok( 'Mail::ContextIO' ) || print "Bail out!\n";
    use_ok( 'Mail::ContextIO::Response' ) || print "Bail out!\n";
}

diag( "Testing Mail::ContextIO $Mail::ContextIO::VERSION, Perl $], $^X" );
