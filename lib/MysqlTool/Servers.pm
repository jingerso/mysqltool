###############################################################################
# Servers.pm 
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

package MysqlTool::Servers;

use strict;

@MysqlTool::Servers::ISA = qw(MysqlTool);

sub display {
    my $self = shift;

    my $q = $self->{'CGI'};
    
    my $reload_nav;

    if( $q->param('new_server') ) {
        if( $q->param('Save') ) {
            $self->edit_server();
            $reload_nav = 1;
        } elsif( $q->param('Cancel') ) {

        } else {
            $self->display_edit_server();
            return;
        }
    }
    
    if( $q->param('delete_server') ) {
        $self->session_dbh()->do("DELETE FROM user_servers WHERE server_id = " . $q->param('delete_server') . " AND user_id = $self->{'user_id'}");
        $reload_nav = 1;
    }
    
    if( $reload_nav ) {
        print "<script language='JavaScript'>";
        print "window.parent.nav.location = window.parent.nav.location;";
        print "</script>";
    }

    my $servers = $self->servers(0, $reload_nav);
    
    my $server_sortby = $q->param('server_sortby') || 'server_id';

    print "<table cellpadding=0 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::light_grey><td><table cellpadding=0 cellspacing=0 border=0 width=100%><tr>";
    print "<td width=19><img src=$MysqlTool::image_dir/servers3.gif border=0 width=19 height=16></td>";
    print "<td nowrap width=100%>$MysqlTool::font<b>Mysql Servers</b></font></td>";
    print "</tr>";
    print "</table></td></tr></table>";
    
    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
    
    my @server_fields = qw(server port admin_user admin_password mysql_version);

    if( %$servers ) {
        print "<tr bgcolor=$MysqlTool::dark_grey>";

        foreach( @server_fields ) {
            if( $server_sortby eq $_ ) {
                print "<td bgcolor=$MysqlTool::dark_color align=center>$MysqlTool::font<font color=white>$_</font></font></td>";
            } else {
                print "<td align=center>$MysqlTool::font<a href=$MysqlTool::start_page?_.in_main._=1&server_sortby=$_>$_</font></td>";
            }
        }

        print "<td align=center>$MysqlTool::font", "status</font></td>";
        print "</tr>";

        my $count = 1;
        foreach my $server_id ( sort { $servers->{$a}->{$server_sortby} cmp $servers->{$b}->{$server_sortby} } keys %$servers ) {
            print "<tr bgcolor=" . ($count++ % 2 == 0 ? $MysqlTool::light_grey : 'white') . ">";

            foreach( @server_fields ) {
                if( $_ eq 'server' ) {
                    print "<td>";
                    print "<table cellpadding=0 cellspacing=0 border=0>";
                    print "<tr>";
                    print "<td width=19><img src=$MysqlTool::image_dir/server2.gif width=19 height=16></td>";
                    print "<td>$MysqlTool::font" . ( $servers->{$server_id}->{'status'} eq 'OK' ? "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server_id>$servers->{$server_id}->{$_}</a>" : $servers->{$server_id}->{$_}) . "</font></td>";
                    print "</tr></table></td>";
                } elsif( $_ eq 'admin_password' ) {
                    print "<td>$MysqlTool::font", ( $servers->{$server_id}->{$_} ne '' ? '*******' : '&nbsp;' ), "</font></td>"; 
                } else {
                    print "<td>$MysqlTool::font", ( $servers->{$server_id}->{$_} ne '' ? $servers->{$server_id}->{$_} : '&nbsp;' ), "</font></td>";
                }
            }
            
            print "<td align=center>$MysqlTool::font$servers->{$server_id}->{'status'}</font></td>";
            print "</tr>";
        }
    }
    
    print "</table>";
}

sub edit_server {
    my $self = shift;

    my $q = $self->{'CGI'};
    #my $dbh = $self->session_dbh;
	my $dbh;

    
    my(@columns, @values);
    foreach( qw(server port username password db) ) {
        push(@columns, $_);

        if( $q->param('id') ) {
            push(@values, "$_ = " . $dbh->quote($q->param($_)));
        } else {
            push(@values, $dbh->quote($q->param($_)));
        }
    }
    
    my $sql;
    if( $q->param('id') ) {
        $sql = "UPDATE user_servers SET " . join(', ', @values) . " WHERE server_id = " . $q->param('id') . " AND user_id = $self->{'user_id'}";
    } else {
        $sql = "INSERT INTO user_servers(user_id, " . join(', ', @columns) . ") VALUES($self->{'user_id'}, " . join(', ', @values) . ")";
    }
    
    #warn "$sql\n";
    $dbh->do($sql);
}

sub display_edit_server {
    my $self = shift;

    my $q = $self->{'CGI'};

    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::dark_grey>", $q->startform( -action => $MysqlTool::start_page, -method => 'POST' ), "<td colspan=2>$MysqlTool::font", ( $q->param('id') ? 'Edit' : 'New' ) . " Server</font></td></tr>";
    
    print $q->hidden( -name => 'new_server' );
    print $q->hidden( -name => 'id' );
    print $q->hidden( -name => '_.in_main._' );

    my $data = {};
    if( $q->param('id') ) {
        my $dbh = $self->session_dbh;
        my $sth = $dbh->prepare("SELECT * FROM user_servers WHERE server_id = " . $q->param('id') . " AND user_id = $self->{'user_id'}");
        $sth->execute;
        $data = $sth->fetchrow_hashref;
        $sth->finish;
    }
    
    print "<tr bgcolor=$MysqlTool::light_grey>";
    print "<td align=right>", $MysqlTool::font, "UserName: </font></td>";
    print "<td>", $q->textfield( -name => 'username', -size => 10, -default => $data->{'username'}), "</td>";
    print "</tr>\n";
    print "<tr bgcolor=$MysqlTool::light_grey>";
    print "<td align=right>", $MysqlTool::font, "Password: </font></td>";
    print "<td>", $q->password_field( -name => 'password', -size => 10, -default => $data->{'password'}), "</td>";
    print "</tr>\n";
    print "<tr bgcolor=$MysqlTool::light_grey>";
    print "<td align=right>", $MysqlTool::font, "Server: </font></td>";
    print "<td>", $q->textfield( -name => 'server', -size => 20, -default => $data->{'server'}), "</td>";
    print "</tr>\n";
    print "<tr bgcolor=$MysqlTool::light_grey>";
    print "<td align=right>", $MysqlTool::font, "Port: </font></td>";
    print "<td>", $q->textfield( -name => 'port', -size => 4, -default => ( $data->{'port'} ? $data->{'port'} : '3306' ) ), "</td>";
    print "</tr>\n";
    print "<tr bgcolor=$MysqlTool::light_grey>";
    print "<td align=right>", $MysqlTool::font, "Database: </font></td>";
    print "<td>", $q->textfield( -name => 'db', -size => 20, -default => $data->{'db'}), "</td>";
    print "</tr>\n";
    
    print "<tr bgcolor=$MysqlTool::dark_grey><td colspan=2 align=center>$MysqlTool::font", $q->submit('Save'), $q->submit('Cancel'), "</font></td></tr>";
    print "</table>";
    print $q->end_form;
}
1;
