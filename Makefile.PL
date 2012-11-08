use strict;
use lib './lib';

use ExtUtils::MakeMaker;
use MysqlTool;

foreach( qw(CGI DBI DBD::mysql Crypt::Blowfish) ) {
    eval "use $_;";
    if( $@ ) {
        die "Error: required module $_ isn't installed. Download $_ from cpan.org and run 'perl Makefile.PL' again.\n<hint>\nsu\nperl -MCPAN -e shell\ninstall $_\n</hint>\n";
    }
    undef($@);
}

print "Generating private key...\n";
# set pkey in msyqltool.conf
my $pkey = &MysqlTool::generate_key();
open(F, "./htdocs/mysqltool.conf") or die "unable to open ./htdocs/mysqltool.conf: $!\n";
my $file;
{
local $/;
$file = <F>;
}
close(F);
$file =~ s/\$MysqlTool::private_key\s*?=\s*?'';/"\$MysqlTool::private_key = '$pkey';"/se;
open(F, ">./htdocs/mysqltool.conf") or die "unable to open ./htdocs/mysqltool.conf: $!\n";
print F $file;
close(F);

# set pkey in MysqlTool.pm as well ..
#open(F, "./lib/MysqlTool.pm") or die "unable to open ./lib/MysqlTool.pm: $!\n";
#undef $/;
#my $file = <F>;
#close(F);
#$file =~ s/\$MysqlTool::private_key\s*?\|\|=\s*?'\S+';/"\$MysqlTool::private_key \|\|= '$pkey';"/se;
#open(F, "> ./lib/MysqlTool.pm") or die "unable to open ./lib/MysqlTool.pm: $!\n";
#print F $file;
#close(F);



# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'MysqlTool',
    'VERSION_FROM'	=> 'lib/MysqlTool.pm', # finds $VERSION
    'PREREQ_PM'		=> { 'CGI' => 2.45,
			     'DBI' => 1.08,
			     'DBD::mysql' => 1.2208,
			     'Crypt::Blowfish' => 2.06
		           }, 
);
