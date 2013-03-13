use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Mail::ContextIO',
    AUTHOR              => q{Les Barstow <Les.Barstow@returnpath.com>},
    VERSION_FROM        => 'lib/Mail/ContextIO.pm',
    ABSTRACT_FROM       => 'lib/Mail/ContextIO.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'mit')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'LWP' => 0,
        'JSON' => 0,
        'Net::OAuth' => 0,

    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Mail-ContextIO-*' },
);
