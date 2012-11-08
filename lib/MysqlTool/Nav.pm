###############################################################################
# Nav.pm 
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

package MysqlTool::Nav;

use strict;

@MysqlTool::Nav::ISA = qw(MysqlTool);

sub display {
    my $self = shift;

    my $q = $self->{'CGI'};
    
    print $q->start_html(-bgcolor => 'white', -link => $MysqlTool::dark_color, -alink => $MysqlTool::dark_color, -vlink => $MysqlTool::dark_color );

    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::dark_grey><td><table cellpadding=0 cellspacing=0 border=0 width=100%><tr>";
    print "<td nowrap>$MysqlTool::font", "<b>Schema Browser</b></font></font></td>";
    print "<td align=right width=100%>$MysqlTool::font<a href='javascript:window.location = window.location'>refresh</a></font></td>";
    print "</tr>";
    print "<tr><td colspan=2 height=2><img src=$MysqlTool::image_dir/transparent.gif width=1 height=2></td></tr>";
    print "</table></td></tr>";
    print "</table>";

    print "<table cellpadding=0 cellspacing=0 border=0 width=100%>";
    print "<tr>";
    print "<td><img src=$MysqlTool::image_dir/servers3.gif border=0></td>";
    print "<td width=100%>$MysqlTool::font" . ($MysqlTool::mode eq '' ? "<font color=$MysqlTool::dark_color>" : "<a href=$MysqlTool::start_page?_.in_main._=1 target=body>") . "<B>Mysql Servers</B>" . ($MysqlTool::mode eq 'SINGLE USER' ? '</font>' : '</a>') . "</font></td>";
    print "</tr>";
    print "</table>";

    $self->display_nav();
    
    print "<table width=100%>";
    print "<tr bgcolor=$MysqlTool::dark_grey><td align=center><a href=http://www.mysql.com target=_top><img src=$MysqlTool::image_dir/mysql-18.gif width=90 height=30 border=0></a></td></tr>";
    print "</table>";
    
    print $q->end_html;
}

sub display_nav {
    my $self = shift;

    my $q = $self->{'CGI'};
    
    my %open_servers = $q->param('open_servers') ? map({ $_, 1 } split(/,/, $q->param('open_servers'))) : ();
    
    my $servers = $self->servers;
    
    unless( %$servers ) {
        #print $MysqlTool::font . "Click <a href=$MysqlTool::start_page?new_server=1&_.in_main._=1 target=body>here</a> to add a server</font>";
		print $MysqlTool::font . "Error: \$MysqlTool::servers not defined!</font>";
    } else {
        foreach( sort { $a <=> $b } keys %$servers ) {
            my $server = $servers->{$_};

            print "<table cellpadding=0 cellspacing=0 border=0>\n";
            print "<tr>\n";
            print "<td width=17>" . ( $server->{'status'} eq 'OK' ? "<a href=$MysqlTool::start_page?_.in_nav._=1&" . $self->state_query_string('open_servers', $server->{'ID'}) . ">" : '' ) . "<img src=$MysqlTool::image_dir/dirtree_" . ( $server->{'status'} eq 'OK' ? ($open_servers{$server->{'ID'}} ? 'minus' : 'plus') . "_" : '' ) . ($server->{'Last'} ? 'elbow' : 'tee') . ".gif border=0 width=17 height=17>" . ( $server->{'status'} eq 'OK' ? '</a>' : '' ) . "</td>\n";
            print "<td width=19><img src=$MysqlTool::image_dir/server2.gif border=0 width=19 height=16></td>\n";
            print "<td nowrap>" . ( $server->{'status'} eq 'OK' ? "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}& target=body>" : '') . "$MysqlTool::font", "$server->{'server'}:$server->{'port'}" . ( $server->{'status'} eq 'OK' ? '</a>' : '') . "</font>$MysqlTool::font" . ( $server->{'status'} ne 'OK' ? " $server->{'status'}" : '') . "</font></td>\n";
            print "</tr>\n";
            print "</table>\n";
        
            if( $open_servers{ $server->{ID} } and ( $server->{'status'} eq 'OK' ) ) {
                
                my %open_databases = map { $_, 1 } split(/,/, $q->param('open_databases'));

                foreach my $db_id ( sort { $a <=> $b } keys %{ $server->{'databases'} } ) {
                    
                    my $db = $server->{'databases'}->{ $db_id };

                    print "<table cellpadding=0 cellspacing=0 border=0>\n";
                    print "<tr>\n";
                    print "<td width=17><img src=$MysqlTool::image_dir/" . ($server->{'Last'} ? 'transparent' : 'dirtree_vertical') . ".gif border=0 width=17 height=17></td>\n";
                    print "<td width=17>" . ( $db->{'status'} eq 'OK' ? "<a href=$MysqlTool::start_page?_.in_nav._=1&" . $self->state_query_string('open_databases', "$server->{ID}.$db->{'ID'}") . ">" : '' ) . "<img src=$MysqlTool::image_dir/dirtree_" . ( $db->{'status'} eq 'OK' ? ($open_databases{"$server->{ID}.$db->{'ID'}"} ? 'minus' : 'plus') . "_" : '' ) . ($db->{'Last'} ? 'elbow' : 'tee') . ".gif border=0 width=17 height=17>" . ( $db->{'status'} eq 'OK' ? '</a>' : '' ) . "</td>\n";
                    print "<td width=21><img src=$MysqlTool::image_dir/db.gif border=0 width=21 height=17></td>\n";
                    print "<td nowrap>" . ( $db->{'status'} eq 'OK' ? "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.db_id._=$db->{ID}&_.in_db._=1 target=body>" : '') . "$MysqlTool::font", "$db->{'db'}" . ( $db->{'status'} eq 'OK' ? '</a>' : '') . "</font>$MysqlTool::font" . ( $db->{'status'} ne 'OK' ? " $db->{'status'}" : '') . "</font></td>\n";
                    print "</tr>\n";
                    print "</table>\n";
                    
                    if( $open_databases{"$server->{ID}.$db->{ID}"} and ( $db->{'status'} eq 'OK' ) ) {
                        my %open_tables     = map { $_, 1 } split(/,/, $q->param('open_tables'));
                        
                        $db->{'dbh'}->do("use $db->{'db'}");
                        my @tables = $db->{'dbh'}->tables;
                        foreach my $table ( @tables ) {
                            print "<table cellpadding=0 cellspacing=0 border=0>\n";
                            print "<tr>\n";
                            print "<td width=17><img src=$MysqlTool::image_dir/" . ($server->{'Last'} ? 'transparent' : 'dirtree_vertical') . ".gif border=0 width=17 height=17></td>\n";
                            print "<td width=17><img src=$MysqlTool::image_dir/" . ($db->{'Last'} ? 'transparent' : 'dirtree_vertical') . ".gif border=0 width=17 height=17></td>\n";
                            print "<td width=17><a href=$MysqlTool::start_page?_.in_nav._=1&" . $self->state_query_string('open_tables', "$server->{ID}.$db->{ID}.$table") . "><img src=$MysqlTool::image_dir/dirtree_" . ($open_tables{"$server->{ID}.$db->{ID}.$table"} ? 'minus' : 'plus') . "_" . ($table eq $tables[$#tables] ? 'elbow' : 'tee') . ".gif border=0 width=17 height=17></a></td>\n";
                            print "<td width=19><img src=$MysqlTool::image_dir/table.gif border=0 width=19 height=17></td>\n";
                            print "<td nowrap>$MysqlTool::font&nbsp;<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.db_id._=$db->{ID}&_.table._=$table&_.in_table._=1 target=body>", $table, "</a></font></td>\n";
                            print "</tr>\n";
                            print "</table>\n";

                            if( $open_tables{"$server->{ID}.$db->{ID}.$table"} ) {
                                my $sth = $db->{'dbh'}->prepare("desc $table");
                                $sth->execute;
                
                                my $x = 1;
                                my $count = $sth->rows;
                
                                while( my $row = $sth->fetch ) {

                                    print "<table cellpadding=0 cellspacing=0 border=0>";
                                    print "<tr>";
                                    print "<td width=16><img src=$MysqlTool::image_dir/" . ($server->{'Last'} ? 'transparent' : 'dirtree_vertical') . ".gif border=0 width=17 height=17></td>";
                                    print "<td width=16><img src=$MysqlTool::image_dir/" . ($db->{'Last'} ? 'transparent' : 'dirtree_vertical') . ".gif border=0 width=17 height=17></td>";
                                    print "<td><img src=$MysqlTool::image_dir/" . ($table eq $tables[$#tables] ? 'transparent' : 'dirtree_vertical') . ".gif border=0 width=17 height=17></td>";
                                    print "<td><img src=$MysqlTool::image_dir/dirtree_" . ($x == $count ? 'elbow' : 'tee') . ".gif border=0 width=17 height=17></td>";
                                    print "<td width=19><img src=$MysqlTool::image_dir/field.gif border=0 width=19 height=17></td>";
                                    print "<td nowrap>$MysqlTool::font&nbsp;", "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.db_id._=$db->{ID}&_.table._=$table&_.in_table._=1&edit=$row->[0] target=body>$row->[0]</a> <font color=#999999>$row->[1]</font></td>";
                                    print "</tr>";
                                    print "</table>";

                                    $x++;
                                }
                                $sth->finish;
                            }
                        }
                    }
                }
            }
        }
    }
}

sub state_query_string {
    my($self, $field, $table) = @_;
    
    my $q = $self->{'CGI'};
    
    my %open_tables = $q->param($field) ? map { $_, 1 } split(/,/, $q->param($field)) : ();
    
    if( $open_tables{ $table } ) {
        delete( $open_tables{ $table } );
    } else {
        $open_tables{ $table } = 1;
    }
    
    my @state_fields = qw(open_tables open_databases open_servers);
    my @q_string;
    
    foreach( @state_fields ) {
        next if( $_ eq $field );
        push(@q_string, "$_=" . ($q->param($_) ? $q->escape($q->param($_)) : ''));
    }
    
    return "$field=" . $q->escape(join(',', keys %open_tables)) . '&' . join('&', @q_string);
}
1;
