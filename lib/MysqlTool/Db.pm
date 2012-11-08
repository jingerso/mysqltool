###############################################################################
# Db.pm 
#
# Copyright (C) 2012 Joseph Ingersoll
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

package MysqlTool::Db;

use strict;

@MysqlTool::Db::ISA = qw(MysqlTool);

sub display {
    my $self = shift;
    my $server = shift;

    my $q = $self->{'CGI'};

    my $database = $server->{'databases'}->{ $q->param('_.db_id._') };
    my $dbh = $database->{'dbh'};
    $dbh->do("use $database->{'db'}");
    
    print "<table cellpadding=0 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::light_grey><td><table cellpadding=0 cellspacing=0 border=0 width=100%><tr>";
    print "<td><img src=$MysqlTool::image_dir/transparent.gif width=17 height=17 border=0></td>";
    print "<td><img src=$MysqlTool::image_dir/dirtree_elbow.gif border=0></td>";
    print "<td width=21><img src=$MysqlTool::image_dir/db.gif border=0 width=21 height=17></td>";
    print "<td>$MysqlTool::font<b>$database->{'db'}</b></font></td>";
    print "<td align=right width=100%>$MysqlTool::font";

    $q->param('_.table._', '') unless $q->param('_.table._');
    my @options;
    push(@options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.db_id._=$database->{ID}&_.sql_frames._=1&_.table._=" . $q->param('_.table._') . " target=body>Execute SQL Statement</a>") unless $q->param('_.in_statement._');
    push(@options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.db_id._=$database->{ID}&_.generate_scripts._=1&_.table._=" . $q->param('_.table._') . " target=body>Generate \"Create Table\" Script</a>");
    print join(' | ', @options);
    print "</font></td>"; 
    print "</tr></table></td></tr>";
    print "</table>";
    
    my $refresh_nav;

    if( $q->param('drop_table') ) {
        my $rv = $dbh->do("DROP TABLE " . $q->param('drop_table'));

        if( $rv ) {
            print "<center>$MysqlTool::font\"Table \"" . $q->param('drop_table') . "\" Dropped!</font></center><br>";
            $refresh_nav = 1;
        } else {
            print "<center>$MysqlTool::font<font color=red>\"DROP TABLE " . $q->param('drop_table') . "\" FAILED!</font></center><br>";
        }
    }
    
    if( $q->param('new_table') || $q->param('edit_table') ) {
        if( $q->param('Save') ) {
            my $rv = $self->edit_table($server);

            if( $rv ) {
                $self->display_edit_table($server, $rv);
            } else {
                $refresh_nav = 1;
            }
        } elsif( $q->param('Cancel') ) {

        } else {
            $self->display_edit_table($server);
        }
    }
    
    if( $refresh_nav ) {
        print "<script language='JavaScript'>";
        print "window.parent.nav.location = window.parent.nav.location;";
        print "</script>";
    }

    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::dark_grey><td><table cellpadding=0 cellspacing=0 border=0 width=100%><tr>";
    print "<td nowrap>$MysqlTool::font<b>Tables</b></td>";
    print "<td align=right width=100%>$MysqlTool::font<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.db_id._=$database->{ID}&new_table=1&_.in_db._=1>New Table</a></font></td>";
    print "</tr>";
    print "</table></td></tr></table>";
    
    my($sql, @columns, $table_sortby, $key);
    
    if( $self->compare_version($server->{'mysql_version'}, '3.23.0') ) {
        $sql = "SHOW TABLE STATUS";
        @columns = qw(Name Type Rows Create_time Update_time Create_options Comment);
        $table_sortby = $q->param('table_sortby') || 'Name';
        $key = 'Name';
    } else {
        $sql = "SHOW TABLES";
        @columns = ('Tables in ' . $database->{'db'} );
        $table_sortby = $q->param('table_sortby') || 'Tables in ' . $database->{'db'};
        $key = 'Tables in ' . $database->{'db'};
    }

    my $sth = $dbh->prepare($sql);
    $sth->execute();
    
    my $db_priv_sortby = $q->param('db_priv_sortby') || 'User';

    if( $sth->rows ) {
        print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
        print "<tr bgcolor=$MysqlTool::dark_grey>";

        foreach( @columns ) {
            if( $_ eq 'Tables_in_' . $database->{'db'} ) {
                print "<td align=center bgcolor=$MysqlTool::dark_color>$MysqlTool::font<font color=white>Table</font></font></td>";
            } elsif( $_ eq $table_sortby ) {
                print "<td align=center bgcolor=$MysqlTool::dark_color>$MysqlTool::font<font color=white>$_</font></font></td>";
            } else {
                print "<td align=center>$MysqlTool::font<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.db_id._=$database->{ID}&table_sortby=$_&db_priv_sortby=$db_priv_sortby&_.in_db._=1>$_</a></font></td>";
            }
        }
        print "<td align=center>$MysqlTool::font", "drop</font></td>";
        print "</tr>";
    
        my $x = 0;
        
        my %rows;

        while( my $row = $sth->fetchrow_hashref ) { $rows{ $row->{$key} } = $row; }

        foreach( sort { $rows{$a}->{$table_sortby} cmp $rows{$b}->{$table_sortby} } keys %rows ) {
            print "<tr bgcolor=" . ($x++ % 2 == 0 ? $MysqlTool::light_grey : 'white') . ">";

            foreach my $column ( @columns ) {
                if( $column eq $key ) {
                    print "<td><table cellpadding=0 cellspacing=0 border=0><tr><td><img src=$MysqlTool::image_dir/table.gif width=19 height=17></td><td>$MysqlTool::font<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.db_id._=$database->{ID}&_.table._=$rows{$_}->{$key}&_.in_table._=1>$rows{$_}->{$key}</a></font></td></tr></table></td>";
                } else {
                    print "<td>$MysqlTool::font" . ($rows{$_}->{$column} ? $rows{$_}->{$column} : '&nbsp;') . "</font></td>";
                }
            }
            print "<td align=center><a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.db_id._=$database->{ID}&_.in_db._=1&drop_table=$rows{$_}->{$key} onClick=\"return confirm('Are you sure you want to delete table: $rows{$_}->{$key}?');\"><img src=$MysqlTool::image_dir/trash.gif border=0></a></td>";
            print "</tr>";
        }
        print "</table>";
    }

    $sth->finish;
    
    if( $server->{'admin_mode'} ) {
        $dbh->do("use mysql");

        print "<hr><a name=GRANT>";
        
        if( $q->param('delete_db_grant') ) {
            unless( $dbh->do("DELETE FROM db WHERE User = " . $dbh->quote($q->param('user')) . " AND Host = " . $dbh->quote($q->param('host')) . " AND Db = BINARY " . $dbh->quote($database->{db})) ) {
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
        
        print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
        print "<tr bgcolor=$MysqlTool::dark_grey><td><table cellpadding=0 cellspacing=0 border=0 width=100%><tr>";
        print "<td nowrap>$MysqlTool::font<b>Grants</b></td>";
        print "<td align=right width=100%>$MysqlTool::font<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.db_id._=$database->{ID}&edit_grant=1&_.in_db._=1&table_sortby=$table_sortby&db_priv_sortby=$db_priv_sortby&_#GRANT>New Grant</a></font></td>";
        print "</tr>";
        print "</table></td></tr></table>";
        
        my @columns = qw(User Host Select_priv Insert_priv Update_priv Delete_priv Create_priv Drop_priv Grant_priv Index_priv Alter_priv);
        my %labels  = map { $_, (split(/_/, $_, 2))[0] } @columns;

        my $sth = $dbh->prepare("SELECT * FROM db WHERE Db = BINARY '$database->{db}' order by $db_priv_sortby");
        $sth->execute;
        
        if( $sth->rows ) {
            print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
            print "<tr bgcolor=$MysqlTool::dark_grey>";
            foreach( @columns ) {
                if( $_ eq $db_priv_sortby ) {
                    print "<td bgcolor=$MysqlTool::dark_color align=center>$MysqlTool::font<font color=white>$labels{$_}</font></font></td>";
                } else {
                    print "<td align=center>$MysqlTool::font<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.db_id._=$database->{ID}&_.in_db._=1&db_priv_sortby=$_&table_sortby=$table_sortby>$labels{$_}</a></font></td>";
                }
            }
            print "<td align=center>$MysqlTool::font", "delete</font></td>";
            print "</tr>";

            my $x;
            while( my $row = $sth->fetchrow_hashref ) {
                print "<tr bgcolor=" . ($x++ % 2 == 0 ? $MysqlTool::light_grey : 'white') . ">";
                foreach( @columns ) {
                    if( $_ eq 'User' ) {
                        print "<td><table cellpadding=0 cellspacing=0 border=0><tr><td><a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.db_id._=$database->{ID}&_.in_db._=1&user=" . $q->escape($row->{User}) . "&host=" . $q->escape($row->{Host}) . "&edit_grant=1&table_sortby=$table_sortby&db_priv_sortby=$db_priv_sortby&_#GRANT><img src=$MysqlTool::image_dir/user2.gif border=0></a></td><td>$MysqlTool::font", "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.db_id._=$database->{ID}&_.in_db._=1&user=" . $q->escape($row->{User}) . "&host=" . $q->escape($row->{Host}) . "&edit_grant=1&table_sortby=$table_sortby&db_priv_sortby=$db_priv_sortby&_#GRANT>$row->{$_}</a></td></tr></table></td>";
                    } else {
                        print "<td>$MysqlTool::font", ($row->{$_} ? $row->{$_} : '&nbsp;'), "</font></td>";
                    }
                }
                print "<td align=center><a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.db_id._=$database->{ID}&_.in_db._=1&user=" . $q->escape($row->{User}) . "&host=" . $q->escape($row->{Host}) . "&delete_db_grant=1#GRANT onClick=\"return confirm('Are you sure you want to delete the database scope grants for $row->{User}\@$row->{Host}?');\"><img src=$MysqlTool::image_dir/trash.gif border=0></a></td>";
                print "</tr>";
            }

            print "</table>";
        }
        $sth->finish;
    }
}

sub edit_table {
    my $self = shift;
    my $server = shift;

    my $q = $self->{'CGI'};
    my $database = $server->{'databases'}->{ $q->param('_.db_id._') };
    my $dbh = $database->{'dbh'};
    $dbh->do("use $database->{db}");

    my @options = qw(avg_row_length checksum delay_key_write max_rows min_rows type);
    my @create;
    foreach( @options ) {
        push(@create, "$_ = " . $q->param($_)) if( $q->param($_) && $q->param($_) ne '--' );
    }
    if($q->param('table_name')=~/[\/\.]/){
        return "Table cannot contain '/' or '.'";
    }
    if( $q->param('edit_table') ) {
        if( $q->param('_.table._') ne $q->param('table_name') ) {
            unless( $dbh->do("ALTER TABLE " . $q->param('_.table._') . " RENAME " . $q->param('table_name')) ) {
                return $dbh->errstr;
            }
            $q->param('_.table._', $q->param('table_name'));
        }

        if( @create || $q->param('comment') ) {
            unless( $dbh->do("ALTER TABLE " . $q->param('table_name') . " " . (@create ? join(' ', @create) : '') . ($q->param('comment') ? ' comment = "' . $q->param('comment') . '"' : '')) ) {
                return $dbh->errstr;
            }
        }
    } else {
    
        my $sql = "CREATE TABLE " . $q->param('table_name') . "( "
                . $q->param('Field') . " "
                . $q->param('Type')
                . ( $q->param('Range') ne '' ? "(" . $q->param('Range') . ")" : '' )
                . ( $q->param('Option') ne '--' ? ' ' . $q->param('Option') : '' )
                . ( $q->param('Null') ? '' : ' NOT NULL' ) 
                . ( $q->param('Primary Key') ? ' PRIMARY KEY' : '' )
                . ( $q->param('Auto Increment') ? ' AUTO_INCREMENT' : '' )
                . ( $q->param('Default') ne '' ? ' DEFAULT ' . $q->param('Default') : '' )
                . ")";

        $sql .= (@create ? join(' ', @create) : '') . ($q->param('comment') ? ' comment = "' . $q->param('comment') . '"' : '');
        #warn "$sql\n";

        return $dbh->do($sql) ? 0 : $dbh->errstr;
    }

    return 0;
}

sub display_edit_table {
    my $self = shift;
    my $server = shift;
    my $message = shift;

    my $q = $self->{'CGI'};
    my $database = $server->{'databases'}->{ $q->param('_.db_id._') };
    my $dbh = $database->{'dbh'};
    $dbh->do("use $database->{db}");

    print $q->startform( -action => $MysqlTool::start_page, -method => 'POST');
    print $q->hidden( -name => 'new_table' );
    print $q->hidden( -name => 'edit_table' );
    print $q->hidden( -name => '_.table._' );
    print $q->hidden( -name => '_.server_id._' );
    print $q->hidden( -name => '_.db_id._' );
    print $q->hidden( -name => '_.in_main._' );
    print $q->hidden( -name => '_.in_db._' );

    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";

    if( $message ) {
        print "<tr><td colspan=2 align=center>$MysqlTool::font<font color=red><b>" . $message . "</b></font></font></td></tr>";
    }
    
    print "<tr bgcolor=$MysqlTool::dark_color><td colspan=2>$MysqlTool::font<font color=white><b>";
    if( $q->param('_.table._') ) {
        print "Edit table: " . $q->param('_.table._');
    } else {
        print "New table";
    }
    print "</b></font></font></td></tr>";
    
    print "<tr bgcolor=$MysqlTool::light_grey>";
    print "<td align=right nowrap>$MysqlTool::font", "Table Name:</font></td>";
    print "<td>$MysqlTool::font", $q->textfield( -name => 'table_name', -size => 50, -maxlength => 64, -default => $q->param('_.table._') ), "</font></td>";
    print "</tr>";
    
    if( $self->compare_version($server->{'mysql_version'}, '3.23.0') ) {
        my $data = {};
        
        if( $q->param('_.table._') ) {
            my $sth = $dbh->prepare("SHOW TABLE STATUS FROM $database->{db} LIKE '" . $q->param('_.table._') . "'");
            $sth->execute;
            $data = $sth->fetchrow_hashref;
            $sth->finish;

            foreach( split(/\s/, $data->{'Create_options'}) ) {
                my($field, $value) = split(/=/, $_);
                $data->{$field} = $value;
            }
        }
        
        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td align=right nowrap>$MysqlTool::font", "Type:</font></td>";
        print "<td>$MysqlTool::font", $q->popup_menu( -name => 'type', values => [ '--', 'ISAM', 'MyISAM', 'HEAP' ], -default => $data->{'Type'} ), "</font></td>";
        print "</tr>";

        print "<tr bgcolor=$MysqlTool::dark_grey><td colspan=2>$MysqlTool::font<font color=$MysqlTool::dark_color>Advanced Options (MyISAM tables only)</font></font></td></tr>";

        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td align=right nowrap>$MysqlTool::font", "Average Row Length:</font></td>";
        print "<td>$MysqlTool::font", $q->textfield( -name => 'avg_row_length', size => 10, -default => $data->{'avg_row_length'} ), "</font></td>";
        print "</tr>";
    
        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td align=right nowrap>$MysqlTool::font", "Checksum:</font></td>";
        print "<td>$MysqlTool::font", $q->popup_menu( -name => 'checksum', values => [ '--', 0, 1 ], -default => $data->{'checksum'} ), "</font></td>";
        print "</tr>";
    
        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td align=right nowrap>$MysqlTool::font", "Comment:</font></td>";
        print "<td>$MysqlTool::font", $q->textfield( -name => 'comment', size => 60, -default => $data->{'Comment'} ), "</font></td>";
        print "</tr>";

        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td align=right nowrap>$MysqlTool::font", "Delay Key Write:</font></td>";
        print "<td>$MysqlTool::font", $q->popup_menu( -name => 'delay_key_write', values => [ '--', 0, 1 ], -default => $data->{'delay_key_write'} ), "</font></td>";
        print "</tr>";
    
        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td align=right nowrap>$MysqlTool::font", "Max Rows:</font></td>";
        print "<td>$MysqlTool::font", $q->textfield( -name => 'max_rows', size => 10, -default => $data->{'max_rows'} ), "</font></td>";
        print "</tr>";
    
        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td align=right nowrap>$MysqlTool::font", "Minimum Rows:</font></td>";
        print "<td>$MysqlTool::font", $q->textfield( -name => 'min_rows', size => 10, -default => $data->{'min_rows'} ), "</font></td>";
        print "</tr>";
    
    }
    
    if( $q->param('new_table') ) {
        print "<tr bgcolor=$MysqlTool::dark_grey><td colspan=2>$MysqlTool::font<font color=$MysqlTool::dark_color>First Field (you'll be able to add more fields later)</font></font></td></tr>";
        
        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td align=right nowrap>$MysqlTool::font", "Field:</font></td>";
        print "<td width=100%>$MysqlTool::font", $q->textfield( -name => 'Field'), "</font></td>";
        print "</tr>";
    
        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td align=right nowrap>$MysqlTool::font", "Type:</font></td>";
        print "<td width=100%>",
              "<table cellpadding=1 cellspacing=0 border=0>",
              "<tr><td>$MysqlTool::font", "Data Type</font></td><td>$MysqlTool::font", "Maximum length/Range</font></td><td>$MysqlTool::font", "Option</font></td></tr>",
              "<tr>",
              "<td>$MysqlTool::font", $q->popup_menu( -name => 'Type', -values => [ qw(TINYINT SMALLINT MEDIUMINT INT BIGINT FLOAT DOUBLE DECIMAL CHAR VARCHAR TINYBLOB BLOB MEDIUMBLOB LONGBLOB TINYTEXT TEXT MEDIUMTEXT LONGTEXT ENUM SET DATE TIME DATETIME TIMESTAMP YEAR) ]), "</font></td>",
              "<td>$MysqlTool::font(" . $q->textfield( -name => 'Range', -size => 40 ) . ")", "</font></td>",
              "<td>$MysqlTool::font" . $q->popup_menu( -name => 'Option', -values => [ '--', 'UNSIGNED', 'BINARY' ] ), "</font></td>",
              "</tr></table>",
              "</td>";
        print "</tr>";
    
        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td align=right nowrap>$MysqlTool::font", "Allow Nulls:</font></td>";
        print "<td width=100%>$MysqlTool::font", $q->checkbox( -name => 'Null', -value => 'NULL', -label => '' ), "</font></td>";
        print "</tr>";
    
        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td align=right nowrap>$MysqlTool::font", "Primary Key:</font></td>";
        print "<td width=100%>$MysqlTool::font", $q->checkbox( -name => 'Primary Key', -value => 'PRIMARY KEY'), "</font></td>";
        print "</tr>";
    
        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td align=right nowrap>$MysqlTool::font", "Default:</font></td>";
        print "<td width=100%>$MysqlTool::font", $q->textfield( -name => 'Default'), " quote strings</font></td>";
        print "</tr>";

        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td align=right nowrap>$MysqlTool::font", "Auto Increment:</font></td>";
        print "<td width=100%>$MysqlTool::font", $q->checkbox( -name => 'Auto Increment', -value => 'AUTO_INCREMENT', -label => '' ), "</font></td>";
        print "</tr>";
    }
    
    print "<tr bgcolor=$MysqlTool::dark_grey><td colspan=2 align=center>$MysqlTool::font", $q->submit('Save'), $q->submit('Cancel'), "</font></td></tr>";
    print "</table>";

    print "</table>";
    print "</form></html>";

    return 1;
}

1;
