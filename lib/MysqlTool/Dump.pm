###############################################################################
# Dump.pm 
#
# Copyright (C) 2001 Dajoba, LLC 
# http://dajoba.com -- info at dajoba dot com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
###############################################################################

package MysqlTool::Dump;

use strict;

@MysqlTool::Dump::ISA = qw(MysqlTool);

sub display_generate_scripts {
    my $self = shift;
    my $server = shift;

    my $q = $self->{'CGI'};
    my $database = $server->{'databases'}->{ $q->param('_.db_id._') };
    my $dbh = $database->{'dbh'};
    $dbh->do("use $database->{db}");
    
    print "<script language='JavaScript'>\n";
    print "function select_all(list, option) {\n";
    print "for( x = 0; x < list.options.length; x++ ) {\n";
    print "list.options[x].selected = option;\n";
    print "}\n";
    print "}\n";
    print "</script>\n";
    
    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::dark_color>", $q->startform( -action => $MysqlTool::start_page, -method => 'POST'), "<td colspan=2>$MysqlTool::font<font color=white><B>Generate \"Create Table\" Script</B></font></font></td></tr>";

    print $q->hidden( -name => '_.generate_scripts._' );
    print $q->hidden( -name => '_.table._' );
    print $q->hidden( -name => '_.server_id._' );
    print $q->hidden( -name => '_.in_main._' );
    print $q->hidden( -name => '_.db_id._' );
    
    print "<tr bgcolor=$MysqlTool::light_grey>";
    print "<td nowrap align=right>$MysqlTool::font", "Include \"DROP TABLE\" statements:</font></td>";
    print "<td width=100%>$MysqlTool::font", $q->checkbox( -name => 'Include drops', -value => 1, label => ''), "</font></td>";
    print "</tr>";
    print "<tr bgcolor=$MysqlTool::light_grey>";
    print "<td nowrap align=right valign=top>$MysqlTool::font", "Tables:<BR><BR>(<a href=\"javascript:void select_all(document.forms[0].tables, true);\">Select All</a> | <a href=\"javascript:void select_all(document.forms[0].tables, false);\">Un-select All</a>)</font></td>";
    print "<td width=100%>$MysqlTool::font", $q->scrolling_list( -name => 'tables', -values => [ $dbh->tables ], -default => $q->param('_.table._'), -size => 10, -multiple => 'true'), "</font></td>";
    print "</tr>";
    print "<tr bgcolor=$MysqlTool::dark_grey><td colspan=2 align=center>$MysqlTool::font", $q->submit('Generate'), "</font></td></tr>";
    print "</table>";
    print $q->end_form;
    
    if( $q->param('Generate') && $q->param('tables') ) {
        print "<hr><pre>";
        print "# database: $database->{db}\n\n\n";

        foreach my $table ( $q->param('tables') ) {
            print "# $table\n";

            if( $q->param('Include drops') ) {
                print "DROP TABLE IF EXISTS $table;\n\n";
            }

            print "CREATE TABLE $table(\n";
            
            my $sth = $dbh->prepare("DESC $table");
            $sth->execute;
            my $count = 1;
            while( my $row = $sth->fetchrow_hashref ) {
                print "\t$row->{Field} " . $row->{Type} . " " . ( $row->{Null} eq 'YES' ? 'NULL' : 'NOT NULL' ) . ( $row->{Extra} ? " " . uc($row->{Extra}) : '') . ( $count++ != $sth->rows ? ",\n" : "" );
            }
            $sth->finish;
            
            my %indices;
            $sth = $dbh->prepare("SHOW INDEX FROM $table");
            $sth->execute;
            $count = 0;
            while( my $row = $sth->fetchrow_hashref ) {
                $indices{ $row->{'Key_name'} }->{'Non_unique'} = $row->{'Non_unique'};
                push(@{ $indices{ $row->{'Key_name'} }->{'fields'} }, $row->{'Column_name'} . ( $row->{'Sub_part'} ? "($row->{'Sub_part'})" : '' ));
                $indices{ $row->{'Key_name'} }->{'order'} = $count++;
            }
            $sth->finish;
            
            if( %indices ) {
                print ",\n";
                $count = 1;
                foreach( sort { $indices{$a}->{'order'} <=> $indices{$b}->{'order'} } keys %indices ) {
                    if( $_ eq 'PRIMARY' ) {
                        print "\tPRIMARY KEY";
                    } elsif( $indices{$_}->{'Non_unique'} == 0 ) {
                        print "\tUNIQUE $_";
                    } else {
                        print "\tINDEX $_";
                    }
                    print " (" . join(', ', @{ $indices{$_}->{'fields'} }) . ")" . ( $count++ != scalar(keys %indices) ? "," : '' ) . "\n";
                }
            } else {
                print "\n";
            }

            print ");\n\n";
        }
        print "</pre>";
    }
}

1;
