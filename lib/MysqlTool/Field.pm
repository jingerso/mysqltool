###############################################################################
# Field.pm 
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

package MysqlTool::Field;

use strict;

@MysqlTool::Field::ISA = qw(MysqlTool);

sub display {
    my $self = shift;
    my $database = shift;

    my $q = $self->{'CGI'};

    my $dbh = $database->{'dbh'};
    $dbh->do("use $database->{db}");

    print "<table cellpadding=0 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::light_grey><td><table cellpadding=0 cellspacing=0 border=0 width=100%><tr><td>";
    print "<table cellpadding=0 cellspacing=0 border=0>";
    print "<tr>";
    print "<td><img src=$MysqlTool::image_dir/transparent.gif border=0 width=17 height=17></td>";
    print "<td><img src=$MysqlTool::image_dir/transparent.gif border=0 width=17 height=17></td>";
    print "<td><img src=$MysqlTool::image_dir/transparent.gif border=0 width=17 height=17></td>";
    print "<td><img src=$MysqlTool::image_dir/dirtree_elbow.gif border=0></td>";
    print "<td width=19><img src=$MysqlTool::image_dir/field.gif border=0 width=19 height=17></td>";
    print "<td>$MysqlTool::font<b>", $q->param('field') . "</b></font></b></font></td>";
    print "</tr>";
    print "</table>";
    print "</td>";
    print "<td align=right>$MysqlTool::font";

    my @options;
    push(@options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&_.table._=" . $q->param('_.table._') . "&_.in_table._=1&edit=" . $q->param('field') . ">Edit</a>");
    push(@options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&_.table._=" . $q->param('_.table._') . "&_.in_table._=1&drop=" . $q->param('field') . " onClick=\"return confirm('Are you sure you want to drop field: " . $q->param('field') . "?')\">Drop</a>");
    print join(' | ', @options);

    print "</font></td></tr></table></td></tr>";
    print "</table>";

    $self->display_grants($database) if( $database->{'admin_mode'} );
}

sub display_grants {
    my $self = shift;
    my $database = shift;
    
    my $q = $self->{'CGI'};
    my $dbh = $database->{'dbh'};
    $dbh->do("use mysql");
    
    my $grant_sortby = $q->param('grant_sortby') || 'User';
    
    if( $q->param('delete_grant') ) {
        unless( $dbh->do("DELETE FROM columns_priv WHERE Column_name = " . $dbh->quote($q->param('field')) . " AND Table_name = " . $dbh->quote($q->param('_.table._')) . " AND User = " . $dbh->quote($q->param('user')) . " AND Host = " . $dbh->quote($q->param('host')) . " AND Db = " . $dbh->quote($database->{db})) ) {
            print "<center>$MysqlTool::font<font color=red><b>" . $dbh->errstr . "</b></font></font></center>";
        }
    }
    
    if( $q->param('edit_grant') ) {
        if( $q->param('Save') ) {
            my $rv = $self->edit_grant($database);

            if( $rv ) {
                print "<center>$MysqlTool::font<font color=red>$rv</font></font></center>";
                $self->display_edit_grant($database);
            } 
        } elsif( $q->param('Cancel') ) {

        } else {
            $self->display_edit_grant($database);
        }
    }

    print "<table cellpadding=2 cellspacing=2 border=0 width=100%><tr bgcolor=$MysqlTool::dark_grey><td><table cellpadding=0 cellspacing=0 border=0 width=100%>";
    print "<tr><td>$MysqlTool::font<b>Grants</b></font></td>";
    print "<td align=right>$MysqlTool::font";
    print "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&grant_sortby=$grant_sortby&edit_grant=1&_.table._=" . $q->param('_.table._') . "&_.in_field._=1&field=" . $q->param('field') . ">New Grant</a>";
    print "</td>";
    print "</tr>";
    print "</table></td></tr></table>";
    
    my @columns = qw(User Host Select Insert Update);

    my $sth = $dbh->prepare("SELECT * FROM columns_priv WHERE Db = " . $dbh->quote($database->{db}) . " AND Table_name = " . $dbh->quote($q->param('_.table._')) . " AND Column_Name = " . $dbh->quote($q->param('field')) . " ORDER BY $grant_sortby");
    $sth->execute;
    
    if( $sth->rows ) {
        print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
        print "<tr bgcolor=$MysqlTool::dark_grey>";
        foreach( @columns ) {
            if( $_ eq $grant_sortby ) {
                print "<td align=center bgcolor=$MysqlTool::dark_color>$MysqlTool::font<font color=white><b>$_</b></font></font></td>";
            } else {
                print "<td align=center>$MysqlTool::font", "$_</font></td>";
            }
        }
        print "<td align=center>$MysqlTool::font", "delete</font></td>";
        print "</tr>";

        my $x = 0;
        while( my $row = $sth->fetchrow_hashref ) {
            print "<tr bgcolor=" . ( $x++ % 2 == 0 ? $MysqlTool::light_grey : 'white' ) . ">";

            my %priv = map { $_, 1 } split(/,/, $row->{'Column_priv'});
            
            foreach( @columns ) {
                if( $_ eq 'User' ) {
                    print "<td><table cellpadding=0 cellspacing=0 border=0><tr><td><a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&_.table._=" . $q->param('_.table._') . "&user=" . $q->escape($row->{User}) . "&host=" . $q->escape($row->{Host}) . "&edit_grant=1&_.in_field._=1&field=" . $q->param('field') . "><img src=$MysqlTool::image_dir/user2.gif border=0></a></td><td>$MysqlTool::font", "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&_.table._=" . $q->param('_.table._') . "&user=" . $q->escape($row->{User}) . "&host=" . $q->escape($row->{Host}) . "&edit_grant=1&_.in_field._=1&field=" . $q->param('field') . ">$row->{$_}</a></td></tr></table></td>";
                } elsif( $_ eq 'Host' ) {
                    print "<td>$MysqlTool::font", ($row->{$_} ? $row->{$_} : '&nbsp;'), "</font></td>";
                } else {
                    print "<td>$MysqlTool::font", ($priv{$_} ? 'Y' : 'N'), "</font></td>";
                } 
            }
            print "<td align=center><a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&_.table._=" . $q->param('_.table._') . "&user=" . $q->escape($row->{User}) . "&host=" . $q->escape($row->{Host}) . "&delete_grant=1&_.in_field._=1&field=" . $q->param('field') . " onClick=\"return confirm('Are you sure you want to delete the column scope grants for $row->{User}\@$row->{Host}?');\"><img src=$MysqlTool::image_dir/trash.gif border=0></a></td>";
            print "</tr>";
        }
        
        print "</table>";
    }

    $sth->finish;
}
1;
