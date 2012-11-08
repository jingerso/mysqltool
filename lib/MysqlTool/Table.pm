###############################################################################
# Table.pm 
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

package MysqlTool::Table;

use strict;

@MysqlTool::Table::ISA = qw(MysqlTool);

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
    print "<td><img src=$MysqlTool::image_dir/dirtree_elbow.gif border=0></td>";
    print "<td width=19><img src=$MysqlTool::image_dir/table.gif border=0 width=19 height=17></td>";
    print "<td>$MysqlTool::font<b>", $q->param('_.table._') . "</b></font></b></font></td>";
    print "</tr>";
    print "</table>";
    print "</td>";
    print "<td align=right>$MysqlTool::font";
    
    $q->param('table_sortby', '') unless $q->param('table_sortby');
    $q->param('index_sortby', '') unless $q->param('index_sortby');
    
    my @table_options;
    if( $self->compare_version($database->{'mysql_version'}, '3.23.0') ) {
        push(@table_options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&edit_table=1&_.table._=" . $q->param('_.table._') . "&_.db_id._=$database->{ID}&_.in_db._=1>Edit</a>");
        push(@table_options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&check=1&_.table._=" . $q->param('_.table._') . "&_.in_table._=1&table_sortby=" . $q->param('table_sortby') . "&index_sortby=" . $q->param('index_sortby') . ">Check</a>");
    }
    if( $self->compare_version($database->{'mysql_version'}, '3.22.7') ) {
        push(@table_options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&optimize=1&_.table._=" . $q->param('_.table._') . "&_.in_table._=1&table_sortby=" . $q->param('table_sortby') . "&index_sortby=" . $q->param('index_sortby') . ">Optimize</a>");
    }
    push(@table_options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&_.in_db._=1&drop_table=" . $q->param('_.table._') . " onClick=\"return confirm('Are you sure you want to drop table: " . $q->param('_.table._') . "?  This can\\'t be undone')\">Drop</a>");
    push(@table_options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&_.sql_frames._=1&_.table._=" . $q->param('_.table._') . "&_.browse._=1 target=body>Browse Records</a>");
    push(@table_options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&_.sql_frames._=1&_.table._=" . $q->param('_.table._') . "&_.browse._=1&_.new_record._=1 target=body>New Record</a>");
    print join(' | ', @table_options);

    print "</font></td></tr></table></td></tr>";
    print "</table>";
    
    if( $q->param('drop') ) {
        if( $dbh->do("ALTER TABLE " . $q->param('_.table._') . " DROP " . $q->param('drop')) ) {
            print "<center>$MysqlTool::font", "DROP Command Succeded!</font></center>";
        } else {
            print "<center>$MysqlTool::font<font color=red>" . $dbh->errstr . "</font></center>";
        }
    }

    if( $q->param('optimize') ) {
        if( $dbh->do("OPTIMIZE TABLE " . $q->param('_.table._')) ) {
            print "<center>$MysqlTool::font", "Optimization Complete!</font></center>";
        } else {
            print "<center>$MysqlTool::font<font color=red>" . $dbh->errstr . "</font></center>";
        }
    }

    if( $q->param('check') ) {
        my $sth = $dbh->prepare("CHECK TABLE " . $q->param('_.table._'));

        if( $sth->execute ) {
            print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
            print "<tr><td colspan=3>$MysqlTool::font<B>Checking table. . .</font></td></tr>";
            print "<tr bgcolor=$MysqlTool::dark_grey>";
            foreach( @{ $sth->{'NAME'} } ) {
                next if( $_ eq 'Table');

                print "<td align=center>$MysqlTool::font$_</td>";
            }
            print "</tr>";
            
            my $x;
            while( my $row = $sth->fetch ) {
                print "<tr bgcolor=" . ($x++ % 2 == 0 ? $MysqlTool::light_grey : 'white' ) . ">";
                foreach(0 .. scalar(@$row) - 1 ) {
                    next if( $_ == 0 );

                    print "<td>$MysqlTool::font", "$row->[$_]</font></td>";
                }
                print "</tr>";
            }
            print "</table><hr>"
        } else {
            print "<center>$MysqlTool::font<font color=red>" . $dbh->errstr . "</font></center>";
        }

        $sth->finish;
    }
    
    if( $self->compare_version($database->{'mysql_version'}, '3.23.0') ) {
        my $sth = $dbh->prepare("SHOW TABLE STATUS FROM $database->{db} LIKE '" . $q->param('_.table._') . "'");

        unless( $sth->execute ) {
            print "<center>$MysqlTool::font<font color=red>" . $dbh->errstr . "</font></center>";
        } else {
            my $data = $sth->fetchrow_hashref;

            print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
            print "<tr bgcolor=$MysqlTool::dark_grey><td colspan=2>$MysqlTool::font<b>Status</b></font></td></tr>";
            print "<tr><td width=50%><table cellspacing=2 cellpadding=2 border=0 width=100% height=100%>";
            foreach( qw(Type Row_format Rows Avg_row_length Data_length Max_data_length Index_length) ) {
                print "<tr bgcolor=$MysqlTool::light_grey>";
                print "<td align=right>$MysqlTool::font$_:</font></td>";
                print "<td width=100%>$MysqlTool::font" . ($data->{$_} ne '' ? $data->{$_} : '&nbsp;') . "</font></td>";
                print "</tr>";
            }
            print "</table></td>";
            print "<td width=50%><table cellspacing=2 cellpadding=2 border=0 width=100% height=100%>";
            foreach( qw(Data_free Auto_increment Create_time Update_time Check_time Create_options Comment) ) {
                print "<tr bgcolor=$MysqlTool::light_grey>";
                print "<td align=right>$MysqlTool::font$_:</font></td>";
                print "<td width=100%>$MysqlTool::font" . (defined($data->{$_}) ? ($data->{$_} ne '' ? $data->{$_} : '&nbsp;') : '&nbsp;') . "</font></td>";
                print "</tr>";
            }
            print "</table></td>";
            print "</tr>";
            print "</table><hr>";
        }
        $sth->finish;
    }
    
    my $index_error;

    if( $q->param('new_index') ) {
        if( $q->param('Save') ) {
            unless( $self->new_index($database) ) {
                $index_error = "<center>$MysqlTool::font<font color=red>" . $dbh->errstr . "</font></font></center>";
            }
        }
    }
    
    if( $q->param('drop_index') ) {
        my $sql = $q->param('drop_index') eq 'PRIMARY' ? "ALTER TABLE " . $q->param('_.table._') . " DROP PRIMARY KEY" : "ALTER TABLE " . $q->param('_.table._') . " DROP INDEX " . $q->param('drop_index');
        #warn "$sql\n";
        
        if( $dbh->do($sql) ) {
            $index_error = "<center>$MysqlTool::font" . "Index dropped!</font></center>";
        } else {
            $index_error = "<center>$MysqlTool::font<font color=red>" . $dbh->errstr . "</font></font></center>";
        }
    }

    $self->display_fields($database);
    $self->display_indices($database, $index_error);
    $self->display_grants($database) if( $database->{'admin_mode'} );
    
}

sub display_fields {
    my $self = shift;
    my $database = shift;

    my $q = $self->{'CGI'};

    my $dbh = $database->{'dbh'};
    $dbh->do("use $database->{db}");

    if( $q->param('edit') || $q->param('new') ) {
        if( $q->param('Save') ) {
            unless( $self->save_field($database) ) {
                print "<center>$MysqlTool::font<font color=red>" . $dbh->errstr . "</font></font></center>";
                $self->display_edit_field($database);
            }
        } elsif( $q->param('Cancel') ) {

        } else {
            $self->display_edit_field($database);
        }
    }
    
    my $sth = $dbh->prepare("desc " . $q->param('_.table._'));
    $sth->execute;
    
    my(%fields, $order);
    while( my $row = $sth->fetchrow_hashref ) {

        $fields{$row->{'Field'}} = $row;
        $fields{$row->{'Field'}}->{'_order_'} = chr(++$order);
    }

    my $table_sortby = $q->param('table_sortby') || '_order_';
    my $index_sortby = $q->param('index_sortby') || '_order_';

    print "<table cellpadding=2 cellspacing=2 border=0 width=100%><tr bgcolor=$MysqlTool::dark_grey><td><table cellpadding=0 cellspacing=0 border=0 width=100%>";
    print "<tr>";
    print "<td>$MysqlTool::font<b>Fields</b></font></td>";
    print "<td align=right>$MysqlTool::font";
    print "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&table_sortby=$table_sortby&index_sortby=$index_sortby&new=1&_.table._=" . $q->param('_.table._') . "&_.in_table._=1>New Field</a>";
    print "</td>";
    print "</tr>";
    print "</table></td></tr></table>";
    
    if( %fields ) {
        print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
        print "<tr bgcolor=$MysqlTool::dark_grey>";

        foreach( @{ $sth->{NAME} }) {
            next if( $_ eq 'Privileges' );

            if( $_ eq $table_sortby ) {
                print "<td bgcolor=$MysqlTool::dark_color align=center>$MysqlTool::font<font color=white><B>$_</B></font></td>";
            } else {
                print "<td align=center>$MysqlTool::font<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&table_sortby=$_&index_sortby=$index_sortby&_.table._=" . $q->param('_.table._') . "&_.in_table._=1>$_</a></font></td>";
            }
        }
        
        print "<td align=center>$MysqlTool::font", "grants</font></td>" if( $database->{'admin_mode'} );
        print "<td align=center>$MysqlTool::font", "drop</font></td>";
        print "</tr>";
    
        my $x = 0;
    
        foreach my $field ( sort { $fields{$a}->{$table_sortby} cmp $fields{$b}->{$table_sortby} } keys %fields ) {

            print "<tr bgcolor=" . ($x % 2 != 0 ? $MysqlTool::light_grey : 'white') . ">";

            foreach( @{ $sth->{NAME} } ) {
                next if( $_ eq 'Privileges' );

                if( $_ eq 'Field' ) {
                    print "<td><table cellpadding=0 cellspacing=0 border=0><tr><td><img src=$MysqlTool::image_dir/field.gif></td><td>$MysqlTool::font<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&index_sortby=$index_sortby&table_sortby=$table_sortby&_.table._=" . $q->param('_.table._') . "&edit=$fields{$field}->{'Field'}&_.in_table._=1>", $fields{$field}->{$_}, "</a></font></td></tr></table></td>";
                } else {
                    print "<td>$MysqlTool::font" . ( defined($fields{$field}->{$_}) ? ($fields{$field}->{$_} ne '' ? $fields{$field}->{$_} : '&nbsp;') : '&nbsp;') . "</td>";
                }
            }
            print "<td align=center>$MysqlTool::font<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&index_sortby=$index_sortby&table_sortby=$table_sortby&_.table._=" . $q->param('_.table._') . "&field=$fields{$field}->{'Field'}&_.in_field._=1><img src=$MysqlTool::image_dir/users.gif border=0></a></font></td>" if( $database->{'admin_mode'} );
            print "<td align=center>$MysqlTool::font<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&index_sortby=$index_sortby&table_sortby=$table_sortby&_.table._=" . $q->param('_.table._') . "&drop=$fields{$field}->{'Field'}&_.in_table._=1 onClick=\"return confirm('Are you sure you want to drop field: $fields{$field}->{'Field'}?')\"><img src=$MysqlTool::image_dir/trash.gif border=0></a></font></td>";
            print "</tr>";
            $x++;
        }
        print "</table>";
    }

    $sth->finish;
}

sub save_field {
    my $self = shift;
    my $database = shift;

    my $q = $self->{'CGI'};
    my $dbh = $database->{'dbh'};

    if( $q->param('new') ) {
        my $sql = "ALTER TABLE " . $q->param('_.table._') . " ADD COLUMN " . $q->param('Field') . " "
                . $q->param('Type')
                . ( $q->param('Range') ne '' ? "(" . $q->param('Range') . ")" : '' )
                . ( $q->param('Option') ne '--' ? ' ' . $q->param('Option') : '' )
                . ( $q->param('Null') ? '' : ' NOT NULL' ) 
                . ( $q->param('Primary Key') ? ' PRIMARY KEY' : '' )
                . ( $q->param('Auto Increment') ? ' AUTO_INCREMENT' : '' )
                . ( $q->param('Default') ne '' ? ' DEFAULT ' . $q->param('Default') : '' );
        #warn "$sql\n";
        $dbh->do($sql) || return 0;
    } else {
        my $sql;

        if( $q->param('Default') ) {
            $sql = "ALTER TABLE " . $q->param('_.table._') . " ALTER " . $q->param('edit') . " SET DEFAULT " . $q->param('Default');
        } else {
            $sql = "ALTER TABLE " . $q->param('_.table._') . " ALTER " . $q->param('edit') . " DROP DEFAULT";
        }
        #warn "$sql\n";
        #$dbh->do($sql) || return 0;

        $sql = "ALTER TABLE " . $q->param('_.table._') . " CHANGE COLUMN " . $q->param('edit') . " " . $q->param('Field') . " "
             . $q->param('Type')
             . ( $q->param('Range') ne '' ? "(" . $q->param('Range') . ")" : '' )
             . ( $q->param('Option') ne '--' ? ' ' . $q->param('Option') : '' )
             . ( $q->param('Null') ? '' : ' NOT NULL' ) 
             . ( $q->param('Primary Key') ? ( $self->already_pkey($database) ? '' : ' PRIMARY KEY' ) : '' )
             . ( $q->param('Auto Increment') ? ' AUTO_INCREMENT' : '' )
             . ( $q->param('Default') ne '' ? ' DEFAULT ' . $q->param('Default') : '' );

        #warn "$sql\n";
        $dbh->do($sql) || return 0;
    }

    return 1;
}

sub already_pkey {
    my $self = shift;
    my $database = shift;

    my $q = $self->{'CGI'};
    my $dbh = $database->{'dbh'};

    my $sth = $dbh->prepare("DESC " . $q->param('_.table._'));
    $sth->execute;
    my $data = {};

    while( $data = $sth->fetchrow_hashref ) {
        last if( $data->{'Field'} eq $q->param('edit') );
    }
    $sth->finish;
    
    return $data->{'Key'} eq 'PRI' ? 1 : 0;
}

sub display_edit_field {
    my $self = shift;
    my $database = shift;

    my $q = $self->{'CGI'};
    my $dbh = $database->{'dbh'};

    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::dark_color>", $q->startform( -action => $MysqlTool::start_page, -method => 'POST' ), "<td colspan=2>$MysqlTool::font<font color=white>";

    my $data = {};
    if( $q->param('new') ) {
        print "New field";
        $data = { map { $_, '' } ('Type', 'Range', 'Option', 'Null', 'Key', 'Primary Key', 'Default', 'Auto Increment', 'Extra') };
    } else {
        my $sth = $dbh->prepare("SHOW COLUMNS FROM " . $q->param('_.table._') . " LIKE '" . $q->param('edit') . "'");
        $sth->execute;
        $data = $sth->fetchrow_hashref;
        
        print "Edit field: " . $q->param('edit');
    }
    print "</font></font></td></tr>";
    
    print $q->hidden( -name => 'edit' );
    print $q->hidden( -name => 'new' );
    print $q->hidden( -name => '_.table._' );
    print $q->hidden( -name => '_.server_id._' );
    print $q->hidden( -name => '_.db_id._' );
    print $q->hidden( -name => '_.in_main._' );
    print $q->hidden( -name => '_.in_table._' );
    print $q->hidden( -name => 'table_sortby' );
    print $q->hidden( -name => 'index_sortby' );

    print "<tr bgcolor=$MysqlTool::light_grey>";
    print "<td align=right nowrap>$MysqlTool::font", "Field:</font></td>";
    print "<td width=100%>$MysqlTool::font", $q->textfield( -name => 'Field', -value => $data->{'Field'} ), "</font></td>";
    print "</tr>";
    
    $data->{Type} =~ /^(\w+)\(?(.*?)\)?\s?(\w+)?$/;
    my($type, $range, $option) = ($1, $2, $3);

    #warn "type: $type\n";
    #warn "range: $range\n";
    #warn "option: $option\n";

    print "<tr bgcolor=$MysqlTool::light_grey>";
    print "<td align=right nowrap>$MysqlTool::font", "Type:</font></td>";
    print "<td width=100%>",
          "<table cellpadding=1 cellspacing=0 border=0>",
          "<tr><td>$MysqlTool::font", "Data Type</font></td><td>$MysqlTool::font", "Maximum length/Range</font></td><td>$MysqlTool::font", "Option</font></td></tr>",
          "<tr>",
          "<td>$MysqlTool::font", $q->popup_menu( -name => 'Type', -default=> uc($type), -values => [ qw(TINYINT SMALLINT MEDIUMINT INT BIGINT FLOAT DOUBLE DECIMAL CHAR VARCHAR TINYBLOB BLOB MEDIUMBLOB LONGBLOB TINYTEXT TEXT MEDIUMTEXT LONGTEXT ENUM SET DATE TIME DATETIME TIMESTAMP YEAR) ]), "</font></td>",
          "<td>$MysqlTool::font(" . $q->textfield( -name => 'Range', -size => 40, -value => $range ) . ")", "</font></td>",
          "<td>$MysqlTool::font" . $q->popup_menu( -name => 'Option', -values => [ '--', 'UNSIGNED', 'BINARY' ], -default => uc($option) ), "</font></td>",
          "</tr></table>",
          "</td>";
    print "</tr>";
    
    print "<tr bgcolor=$MysqlTool::light_grey>";
    print "<td align=right nowrap>$MysqlTool::font", "Allow Nulls:</font></td>";
    print "<td width=100%>$MysqlTool::font", $q->checkbox( -name => 'Null', -value => 'NULL', -checked => ($data->{'Null'} eq 'YES' ? 'checked' : ''), -label => '' ), "</font></td>";
    print "</tr>";
    
    print "<tr bgcolor=$MysqlTool::light_grey>";
    print "<td align=right nowrap>$MysqlTool::font", "Primary Key:</font></td>";
    print "<td width=100%>$MysqlTool::font", $q->checkbox( -name => 'Primary Key', -value => 'PRIMARY KEY', -checked => ($data->{'Key'} eq 'PRI' ? 'checked' : ''), -label => '' ), "</font></td>";
    print "</tr>";
    
    print "<tr bgcolor=$MysqlTool::light_grey>";
    print "<td align=right nowrap>$MysqlTool::font", "Default:</font></td>";
    print "<td width=100%>$MysqlTool::font", $q->textfield( -name => 'Default', -value => $data->{'Default'} ), " quote strings</font></td>";
    print "</tr>";

    print "<tr bgcolor=$MysqlTool::light_grey>";
    print "<td align=right nowrap>$MysqlTool::font", "Auto Increment:</font></td>";
    print "<td width=100%>$MysqlTool::font", $q->checkbox( -name => 'Auto Increment', -value => 'AUTO_INCREMENT', -checked => ($data->{'Extra'} eq 'auto_increment' ? 'checked' : ''), -label => '' ), "</font></td>";
    print "</tr>";

    print "<tr bgcolor=$MysqlTool::dark_grey><td colspan=2 align=center>$MysqlTool::font<font color=$MysqlTool::dark_color>", $q->submit('Save'), $q->submit('Cancel'), "</font></font></td></tr>";
    print "</table>";
    print $q->endform;
}

sub display_indices {
    my $self = shift;
    my $database = shift;
    my $error = shift;
    
    my $q = $self->{'CGI'};

    my $dbh = $database->{'dbh'};
    $dbh->do("use $database->{db}");

    print "<hr>";
    print "<center>$MysqlTool::font<font color=red>", $error, "</font></font></center>" if( $error );

    if( $q->param('new_index') ) {
        if( $q->param('Save') ) {
            if( $error ) {
                $self->display_new_index($database);
            }
        } elsif( $q->param('Cancel') ) {

        } else {
            $self->display_new_index($database);
        }
    }
    
    my $table_sortby = $q->param('table_sortby') || '_order_';
    my $index_sortby = $q->param('index_sortby') || '_order_';
    
    my $sth = $dbh->prepare("show index from " . $q->param('_.table._'));
    $sth->execute;
    
    my(%indices, $order);
    while( my $row = $sth->fetchrow_hashref ) {
        my $key = chr(++$order);
        $indices{$key} = $row;
        $indices{$key}->{'_order_'} = $key;
    }
    
    print "<table cellpadding=2 cellspacing=2 border=0 width=100%><tr bgcolor=$MysqlTool::dark_grey><td><table cellpadding=0 cellspacing=0 border=0 width=100%>";
    print "<tr><td>$MysqlTool::font<b>Indices</b></font></td>";
    print "<td align=right>$MysqlTool::font";
    print "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&table_sortby=$table_sortby&index_sortby=$index_sortby&new_index=1&_.table._=" . $q->param('_.table._') . "&_.in_table._=1#INDEX>New Index</a>";
    print "</td>";
    print "</tr>";
    print "</table></td></tr></table>";

    if( %indices ) {

        print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
        print "<tr bgcolor=$MysqlTool::dark_grey>";

        foreach( @{ $sth->{NAME} }) {
            next if( $_ eq 'Table');

            if( $_ eq $index_sortby ) {
                print "<td bgcolor=$MysqlTool::dark_color align=center>$MysqlTool::font<font color=white><B>$_</B></font></td>";
            } else {
                print "<td align=center>$MysqlTool::font<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&index_sortby=$_&table_sortby=$table_sortby&_.table._=" . $q->param('_.table._') . "&_.in_table._=1#INDEX>$_</a></font></td>";
            }
        }
        print "<td align=center>$MysqlTool::font", "drop</font></td>";
        print "</tr>";
        
        my $x = 0;
    
        foreach my $index ( sort { $indices{$a}->{$index_sortby} cmp $indices{$b}->{$index_sortby} } keys %indices ) {

            print "<tr bgcolor=" . ($x % 2 != 0 ? $MysqlTool::light_grey : 'white') . ">";

            foreach( @{ $sth->{NAME} } ) {
                next if( $_ eq 'Table');
                print "<td>$MysqlTool::font" . (defined($indices{$index}->{$_}) ? ( $indices{$index}->{$_} ne '' ? $indices{$index}->{$_} : '&nbsp;' )  : '&nbsp;') . "</td>";
            }

            print "<td align=center>$MysqlTool::font";
            print "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=", $q->param('_.server_id._'), "&_.db_id._=$database->{ID}&index_sortby=$index_sortby&table_sortby=$table_sortby&_.table._=", $q->param('_.table._'), "&drop_index=$indices{$index}->{'Key_name'}&_.in_table._=1#INDEX onClick=\"return confirm('Are you sure you want to drop index: $indices{$index}->{'Key_name'}?')\">";
            print "<img src=$MysqlTool::image_dir/trash.gif border=0></a></font></td>";
            print "</tr>";
            $x++;
        }
        print "</table>";
    }

    $sth->finish;
}

sub new_index {
    my $self = shift;
    my $database = shift;

    my $q = $self->{'CGI'};
    my $dbh = $database->{'dbh'};
    
    my $sql = "ALTER TABLE " . $q->param('_.table._') . " ADD ";

    if( $q->param('Primary Key') ) {
        $sql .= "PRIMARY KEY ";
    } elsif( $q->param('Unique') ) {
        $sql .= "UNIQUE ";
    } else {
        $sql .= "INDEX ";
    }

    $sql .= $q->param('Name') . " ";
    
    my @fields;
    foreach( split(/\s/, "@{ [ $q->param('Fields') ] }") ) {
        if( $q->param('Prefix_' . $_) ) {
            push(@fields, $_ . "(" . $q->param('Prefix_' . $_) . ")");
        } else {
            push(@fields, $_);
        }
    }

    $sql .= "(" . join(', ', @fields) . ")";
    
    #warn "$sql\n";
    return $dbh->do($sql);
}

sub display_new_index {
    my $self = shift;
    my $database = shift;

    my $q = $self->{'CGI'};
    my $dbh = $database->{'dbh'};

    print "<a name='INDEX'>";
    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::dark_color>", $q->startform( -action => $MysqlTool::start_page, -method => 'POST' ), "<td colspan=2>$MysqlTool::font<font color=white><b>New Index</b></font></font></td></tr>";
    
    print $q->hidden( -name => 'new_index' );
    print $q->hidden( -name => '_.table._' );
    print $q->hidden( -name => '_.server_id._' );
    print $q->hidden( -name => '_.in_main._' );
    print $q->hidden( -name => '_.db_id._' );
    print $q->hidden( -name => '_.in_table._' );
    print $q->hidden( -name => 'table_sortby' );
    print $q->hidden( -name => 'index_sortby' );

    print "<tr bgcolor=$MysqlTool::light_grey>";
    print "<td nowrap align=right>$MysqlTool::font", "Name:</font></td>";
    print "<td width=100%>$MysqlTool::font", $q->textfield( -name => 'Name', -size => 40 ), "</font></td>";
    print "</tr>";
    
    print "<tr bgcolor=$MysqlTool::light_grey>";
    print "<td nowrap align=right>$MysqlTool::font", "Primary Key:</font></td>";
    print "<td width=100%>$MysqlTool::font", $q->checkbox( -name => 'Primary Key', -value => 1, -label => '' ), "</font></td>";
    print "</tr>";
    
    if( $self->compare_version($database->{'mysql_version'}, '3.23.0') ) {
        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td nowrap align=right>$MysqlTool::font", "Unique:</font></td>";
        print "<td width=100%>$MysqlTool::font", $q->checkbox( -name => 'Unique', -value => 1, -label => '' ), "</font></td>";
        print "</tr>";
    }
    print "</table>";

    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::dark_grey>";
    print "<td>&nbsp;</td>";
    print "<td>$MysqlTool::font", "Field</font></td>";
    print "<td>$MysqlTool::font", "Type</font></td>";
    print "<td>$MysqlTool::font", "Null</font></td>";
    print "<td>$MysqlTool::font", "Key</font></td>";
    print "<td>$MysqlTool::font", "Prefix (required for text and blob columns)</font></td>";
    print "</tr>";

    my $sth = $dbh->prepare("SHOW COLUMNS FROM " . $q->param('_.table._'));
    $sth->execute;
    my $x = 0;
    while( my $row = $sth->fetch ) {
        print "<tr bgcolor=" . ($x++ % 2 != 0 ? $MysqlTool::light_grey : 'white') . ">";
        print "<td align=center>$MysqlTool::font", $q->checkbox( -name => 'Fields', -value => $row->[0], -label=>''), "</font></td>";
        print "<td>$MysqlTool::font", $row->[0], "</font></td>";
        print "<td nowrap>$MysqlTool::font", $row->[1], "</font></td>";
        print "<td nowrap>$MysqlTool::font", ($row->[2] ? $row->[2] : '&nbsp;'), "</font></td>";
        print "<td nowrap>$MysqlTool::font", ($row->[3] ? $row->[3] : '&nbsp;'), "</font></td>";
        print "<td width=100%>$MysqlTool::font", ( $row->[1] =~ /(char|blob|text)/ ? $q->textfield( -name => 'Prefix_' . $row->[0], -size => 5 ) : '&nbsp;' ), "</font></td>";
        print "</tr>";
    }
    $sth->finish;
    print "</table>";

    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::dark_grey><td colspan=2 align=center>$MysqlTool::font<font color=$MysqlTool::dark_color>", $q->submit('Save'), $q->submit('Cancel'), "</font></font></td></tr>";
    print "</table>";
    print $q->endform;
}

sub display_grants {
    my $self = shift;
    my $database = shift;
    
    my $q = $self->{'CGI'};
    my $dbh = $database->{'dbh'};
    $dbh->do("use mysql");
    
    my $table_sortby = $q->param('table_sortby') || '_order_';
    my $index_sortby = $q->param('index_sortby') || '_order_';
    
    print "<hr><a name=GRANT>";
    
    if( $q->param('delete_grant') ) {
        if( $dbh->do("DELETE FROM tables_priv WHERE Table_name = " . $dbh->quote($q->param('_.table._')) . " AND User = " . $dbh->quote($q->param('user')) . " AND Host = " . $dbh->quote($q->param('host')) . " AND Db = " . $dbh->quote($database->{db})) ) {
            unless( $dbh->do("DELETE FROM columns_priv WHERE Table_name = " . $dbh->quote($q->param('_.table._')) . " AND User = " . $dbh->quote($q->param('user')) . " AND Host = " . $dbh->quote($q->param('host')) . " AND Db = " . $dbh->quote($database->{db})) ) {
                print "<center>$MysqlTool::font<font color=red><b>" . $dbh->errstr . "</b></font></font></center>";
            }
        } else {
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
    print "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&table_sortby=$table_sortby&index_sortby=$index_sortby&edit_grant=1&_.table._=" . $q->param('_.table._') . "&_.in_table._=1#GRANT>New Grant</a>";
    print "</td>";
    print "</tr>";
    print "</table></td></tr></table>";
    
    my @columns = qw(User Host Select Insert Update Delete Create Drop Grant Index Alter);

    my $sth = $dbh->prepare("SELECT * FROM tables_priv WHERE Db = " . $dbh->quote($database->{db}) . " AND Table_name = " . $dbh->quote($q->param('_.table._')) . " ORDER BY Host, User");
    $sth->execute;
    
    if( $sth->rows ) {
        print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
        print "<tr bgcolor=$MysqlTool::dark_grey>";
        foreach( @columns ) {
            if( $_ eq 'User' ) {
                print "<td align=center bgcolor=$MysqlTool::dark_color>$MysqlTool::font<font color=white><b>$_</b></font></font></td>";
            } else {
                print "<td align=center>$MysqlTool::font$_</font></td>";
            }
        }
        print "<td align=center>$MysqlTool::font", "delete</font></td>";
        print "</tr>";

        my $x = 0;
        while( my $row = $sth->fetchrow_hashref ) {
            print "<tr bgcolor=" . ( $x++ % 2 == 0 ? $MysqlTool::light_grey : 'white' ) . ">";

            my %priv = map { $_, 1 } split(/,/, $row->{'Table_priv'});
            
            foreach( @columns ) {
                if( $_ eq 'User' ) {
                    print "<td><table cellpadding=0 cellspacing=0 border=0><tr><td><a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&_.table._=" . $q->param('_.table._') . "&user=" . $q->escape($row->{User}) . "&host=" . $q->escape($row->{Host}) . "&edit_grant=1&_.in_table._=1&table_sortby=$table_sortby&index_sortby=$index_sortby#GRANT><img src=$MysqlTool::image_dir/user2.gif border=0></a></td><td>$MysqlTool::font", "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&_.table._=" . $q->param('_.table._') . "&user=" . $q->escape($row->{User}) . "&host=" . $q->escape($row->{Host}) . "&table_sortby=$table_sortby&index_sortby=$index_sortby&edit_grant=1&_.in_table._=1#GRANT>$row->{$_}</a></td></tr></table></td>";
                } elsif( $_ eq 'Host' ) {
                    print "<td>$MysqlTool::font", ($row->{$_} ? $row->{$_} : '&nbsp;'), "</font></td>";
                } else {
                    print "<td>$MysqlTool::font", ($priv{$_} ? 'Y' : 'N'), "</font></td>";
                } 
            }
            print "<td align=center><a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&_.table._=" . $q->param('_.table._') . "&user=" . $q->escape($row->{User}) . "&host=" . $q->escape($row->{Host}) . "&table_sortby=$table_sortby&index_sortby=$index_sortby&delete_grant=1&_.in_table._=1#GRANT onClick=\"return confirm('Are you sure you want to delete the table and column scope grants for $row->{User}\@$row->{Host}?');\"><img src=$MysqlTool::image_dir/trash.gif border=0></a></td>";
            print "</tr>";
        }
        
        print "</table>";
    }

    $sth->finish;
}

sub display_load_data {
    my $self = shift;

    my $q = $self->{'CGI'};
    my $server = $self->servers($q->param('_.server_id._'));
    my $dbh = $server->{'dbh'};

    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>", $q->start_multipart_form( -action => $MysqlTool::start_page, -method => 'POST' );
    print "<tr bgcolor=$MysqlTool::dark_color><td colspan=2>$MysqlTool::font<b><font color=white>Import Data</font></b></font></td></tr>";

    print $q->hidden( -name => 'load_data' );
    print $q->hidden( -name => '_.table._' );
    print $q->hidden( -name => '_.server_id._' );
    print $q->hidden( -name => '_.in_main._' );

    print "<tr bgcolor=$MysqlTool::light_grey>";
    print "<td nowrap align=right>$MysqlTool::font", "File:</font></td>";
    print "<td width=100%>$MysqlTool::font", $q->filefield( -name => 'file', -size => 40 ), "</font></td>";
    print "</tr>";
    
    if( $self->compare_version($server->{'mysql_version'}, '3.23.0') ) {
        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td nowrap align=right>$MysqlTool::font", "Low Priority:</font></td>";
        print "<td width=100%>$MysqlTool::font", $q->checkbox( -name => 'LOW_PRIORITY', -value => 1, -label => ''), "</font></td>";
        print "</tr>";
    }
    
    print "<tr bgcolor=$MysqlTool::light_grey>";
    print "<td nowrap align=right>$MysqlTool::font", "Current Data:</font></td>";
    print "<td width=100%>$MysqlTool::font", $q->popup_menu( -name => 'current_data', -values => [ '--', 'Ignore', 'Replace' ] ), "</font></td>";
    print "</tr>";
    
    print "<tr bgcolor=$MysqlTool::light_grey>";
    print "<td nowrap align=right>$MysqlTool::font", "Ignore this number of lines:</font></td>";
    print "<td width=100%>$MysqlTool::font", $q->textfield( -name => 'ignore', -size => 5, -value => 0), "</font></td>";
    print "</tr>";

    print "<tr bgcolor=$MysqlTool::dark_grey>";
    print "<td colspan=2 align=center>$MysqlTool::font";
    print $q->submit('Import');
    print $q->submit('Cancel');
    print "</td>";
    print "</tr>";

    print "</table><hr>";
}
1;
