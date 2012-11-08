#!/usr/bin/perl
#
# generate 112-byte shared secret for NicTool client/server

srand( time() ^ ($$ + ($$ << 15)) );

my @chars = ( "a" .. "z", "A" .. "Z", 0 .. 9 ); 
# TODO - could probably use ANY ascii character, but this is what openSRS does.
my $password = join("", @chars[ map { rand @chars } ( 1 .. 56 ) ]);

print "\n$password\n\n";
print "Update \$MysqlTool::private_key in mysqltool.conf with the 56 byte key generated above.\n";

