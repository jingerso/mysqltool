###############################################################################
# Query.pm 
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

package MysqlTool::Query;

use strict;

@MysqlTool::Query::ISA = qw(MysqlTool);

sub display_statement_frame {
    my $self = shift;

    my $q = $self->{'CGI'};

    print "<table cellpadding=2 cellspacing=0 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::dark_grey><form action=$MysqlTool::start_page method=POST target=result>";
    
    print $q->hidden( -name => '_.server_id._' );
    print $q->hidden( -name => '_.in_main._' );
    print $q->hidden( -name => '_.db_id._' );
    print $q->hidden( -name => '_.in_result._', -value => 1 );

    print "<td>$MysqlTool::font<font size=2 color=$MysqlTool::dark_color>Execute SQL Statement</td>";
    print "<td align=right>$MysqlTool::font", "LIMIT Clause: Start at row #", $q->textfield( -name => '_.start._', -value => 1, -size => 6), " &nbsp; Display ", $q->textfield( -name => '_.limit._', -value => 100, -size => 4), " rows per page.</font></td>";
    print "</tr>";
    print "<tr bgcolor=$MysqlTool::light_grey><td align=center colspan=2>";
    print $q->textarea( -name => '_.statement._', -rows => 6, cols=> 70, -default => ($q->param('_.table._') ? "SELECT * FROM " . $q->param('_.table._') : '') );
    print "</td></tr>";
    print "<tr><td colspan=2 align=center bgcolor=$MysqlTool::dark_grey>$MysqlTool::font", $q->submit( -name => '_.Execute._', -value => 'Execute' ), 
          $q->submit( -name => 'Clear', -onClick => "document.forms[0].elements[6].value = ''; return false"  );
    print "</table>";
}

sub display_result_frame {
    my $self = shift;
    my $database = shift;

    my $q = $self->{'CGI'};
    my $dbh = $database->{'dbh'};
    $dbh->do("use $database->{db}");

    return unless $q->param('_.Execute._');
    
    if( $q->param('_.delete._') ) {
        $dbh->do("DELETE FROM " . $q->param('_.table._') . " WHERE " . join(' AND ', map("$_ = " . $dbh->quote($q->param($_)), split(/,/, $q->param('_.pkey._')))));
    }
    
    my $sql = $q->param('_.statement._');
    my $command;
    #if( $sql =~ /^(\s*?)SELECT/i ) { ## TODO abe, what about "select 1+1+5" statements? we shouldn't add LIMIT..
    if( $sql =~ /^(\s*?)SELECT/i && $sql =~ / FROM /i) { 
        $sql .= " LIMIT " . ($q->param('_.start._') - 1) . ", " . $q->param('_.limit._');
        $command = 'SELECT';
    }
    
    my $sth = $dbh->prepare($sql);
        
	## TODO - we need a real mysql SQL statement parser here
	##		  there has to be misc (minor) problems with our regex's.. --ai 2/10/01
    
	unless( $sth->execute ) {
        print "<center>$MysqlTool::font<font color=red>" . $dbh->errstr . "</font></center><br>";
    } else {
        if( $command eq 'SELECT' ) {
			$sql =~ /^(.+?)FROM\s+(.+?)\s+(WHERE|LIMIT|ORDER|GROUP|LEFT|RIGHT|CROSS|INNER|STRAIGHT_JOIN|NATURAL)\s/i;

            my @tables = split(/,/, $2);
            foreach(@tables) { s/\s//g; }

			# KLUGE
			$sql =~ s/\".*\"//; $sql =~ s/\'.*\'//;
			push(@tables,"x") if ($sql =~ /FROM.* JOIN /i); # to force #$tables > 0, so New Record not shown

            $sql = $q->param('_.statement._');
            $sql =~ s/SELECT(.+?)FROM /SELECT COUNT(*) FROM /i;

            my $count_sth = $dbh->prepare($sql);
            $count_sth->execute;
            my $count = $count_sth->fetch->[0];
            
            my $columns = $sth->{NAME};
            my $types   = $sth->{TYPE};
            my $pkeys   = $sth->{mysql_is_pri_key};
            my $blobs   = $sth->{mysql_is_blob};
            my @pkey_fields = map $columns->[$_], grep $pkeys->[$_], 0 .. scalar(@$columns) - 1;
            
            my $table;
            $table = $tables[0] if( $#tables == 0 );
			
            my $end = ( $q->param('_.start._') - 1 + $q->param('_.limit._'));
            $end = $count if( $end > $count );
            
            print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
            print "<tr><td>$MysqlTool::font";
            print "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&_.in_result._=1&_.start._=" . ( $q->param('_.start._') - $q->param('_.limit._') ) . "&_.limit._=" . $q->param('_.limit._') . "&_.statement._=" . $q->escape($q->param('_.statement._')) . "&_.Execute._=Execute>&lt;&lt; previous</a> &nbsp; &nbsp; " if( $q->param('_.start._') != 1 );
            print "Displaying rows " . $q->param('_.start._') . " - " . "$end of " . $count . " &nbsp; &nbsp; ";
            print "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&_.in_result._=1&_.start._=" . ( $q->param('_.start._') + $q->param('_.limit._') ) . "&_.limit._=" . $q->param('_.limit._') . "&_.statement._=" . $q->escape($q->param('_.statement._')) . "&_.Execute._=Execute>next &gt;&gt;</a>" unless( $q->param('_.start._') + $q->param('_.limit._') > $count );
            print "</font></td>";
			if ($table) {
            	print "<td align=right>$MysqlTool::font", "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&_.in_result._=1&_.start._=" . $q->param('_.start._') . "&_.limit._=" . $q->param('_.limit._') . "&_.statement._=" . $q->escape($q->param('_.statement._')) . "&_.Execute._=Execute&_.new_record._=1&_.pkey._=" . join(',', @pkey_fields) . "&_.table._=$table>New Record</a></font></td>";
			} else {
				print "<td>&nbsp;</td>";
			}
            print "</tr>";
            print "</table>";
            
            print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
            print "<tr bgcolor=$MysqlTool::dark_grey>";

            if( $#tables == 0 && @pkey_fields ) {
                print "<td align=center width=16>$MysqlTool::font", "delete</td>";
                print "<td align=center width=16>$MysqlTool::font", "edit</td>" unless( $#pkey_fields == (scalar(@$columns) - 1) );
            }
            
            foreach(0 .. scalar(@$columns) - 1 ) {
                print "<td align=center>$MysqlTool::font$columns->[$_]</font></td>";
            }
            print "</tr>";
        
            my $x = 0;
            while( my $row = $sth->fetch ) {
                if( ($x % $MysqlTool::row_header_frequency == 0) && ($x != $end) && ($x != 0)) {
                    print "</table>";
                    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
                    print "<tr bgcolor=$MysqlTool::dark_grey>";
                    if( $#tables == 0 && @pkey_fields ) {
                        print "<td align=center>$MysqlTool::font", "delete</td>";
                        print "<td align=center>$MysqlTool::font", "edit</td>" unless( $#pkey_fields == (scalar(@$columns) - 1) );
                    }
                    foreach(0 .. scalar(@$columns) - 1 ) {
                        print "<td align=center>$MysqlTool::font$columns->[$_]</font></td>";
                    }
                    print "</tr>";
                }
                
                print "<tr bgcolor=" . ($x % 2 == 0 ? $MysqlTool::light_grey : 'white') . ">";
                
                if( $#tables == 0 && @pkey_fields ) {
                    my %pkey_values;
                    foreach( 0 .. scalar(@$columns) - 1 ) {
                        $pkey_values{ $columns->[$_] } = $row->[$_] if( $pkeys->[$_] );
                    }

                    print "<td align=center width=16><a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&_.in_result._=1&_.start._=" . $q->param('_.start._') . "&_.limit._=" . $q->param('_.limit._') . "&_.statement._=" . $q->escape($q->param('_.statement._')) . "&_.Execute._=Execute&_.delete._=1&_.pkey._=" . join(',', @pkey_fields) . '&' . join('&', map $q->escape($_) . '=' . $q->escape($pkey_values{$_}), keys %pkey_values) . "&_.table._=$table onClick=\"return confirm('Are you sure you want to delete this record?')\"><img src=$MysqlTool::image_dir/trash.gif border=0></a></td>";
                    print "<td align=center width=16><a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&_.in_result._=1&_.start._=" . $q->param('_.start._') . "&_.limit._=" . $q->param('_.limit._') . "&_.statement._=" . $q->escape($q->param('_.statement._')) . "&_.Execute._=Execute&_.edit._=1&_.pkey._=" . join(',', @pkey_fields) . '&' . join('&', map $q->escape($_) . '=' . $q->escape($pkey_values{$_}), keys %pkey_values) . "&_.table._=$table><img src=$MysqlTool::image_dir/edit_pad.gif border=0></a></td>" unless( $#pkey_fields == (scalar(@$columns) - 1) );
                }
                
                my $y = 0;
                foreach( @$row ) {
                    if( defined $_ ) {
                        s/</&lt;/gm;
                        s/>/&gt;/gm;
                        print "<td>$MysqlTool::font" . $_ . "</td>";
                    } else {
                        print "<td>$MysqlTool::font" . "&nbsp;</td>";
                    }
                }
                print "</tr>";
				$x++;
            }
            print "</table>";
        } else {
            print "<center>$MysqlTool::font" . "Query OK, " . $sth->rows . " row(s) affected!</font></center><br>";
        }
    }

    $sth->finish;
}

sub display_edit_record {
    my $self = shift;
    my $database = shift;

    my $q = $self->{CGI};
    my $dbh = $database->{'dbh'};
    $dbh->do("use $database->{db}");
    
    my($record, $fields, $lengths, $pkeys);

    if( $q->param('_.edit._') ) {
        my $sql = "SELECT * FROM " . $q->param('_.table._') . ( $q->param('_.edit._') ? " WHERE " . join(' AND ', map("$_ = " . $dbh->quote($q->param($_)), split(/,/, $q->param('_.pkey._')))) : '') . " LIMIT 1";
        my $sth = $dbh->prepare($sql);
    
        unless( $sth->execute ) {
            print "<center>$MysqlTool::font<font color=red>" . $dbh->errstr . "</font></center><br>";
            $sth->finish;
            return 0;
        }
        $record  = $sth->fetch || [];
        $fields  = $sth->{NAME};
        $lengths = $sth->{mysql_length};
        $pkeys   = $sth->{mysql_is_pri_key};
        
        my $types = $sth->{mysql_type};
        my $def   = $self->column_definitions($database, $q->param('_.table._'));

        foreach(0 .. scalar(@$types) - 1) {
            if( $def->[$_]->{'Type'} =~ /^(set|enum)/i ) {
                $lengths->[$_] = $def->[$_]->{'Type'};
            }
        }
        
        $sth->finish;
    } else {
        my $sth = $dbh->prepare("desc " . $q->param('_.table._'));
        $sth->execute;

	
        while( my $row = $sth->fetchrow_hashref ) {
            push(@$fields, $row->{Field});
            
            if( $row->{Type} =~ /^(enum|set)/i ) {
                push(@$lengths, $row->{Type});
            } elsif( $row->{Type} =~ /(BLOB|TEXT)/i ) {
                push(@$lengths, 255 );
            } else {
                $row->{Type} =~ /^(\w+)\(?(.*?)\)?\s?(\w+)?$/;
                
                if( $2 ) {
                    push(@$lengths, $2);
                } else {
                    push(@$lengths, 40);
                }
            }
        }
        
        $record = [];
        $pkeys = [];
        $sth->finish;
    }
    
    print "<center><table cellpadding=2 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::dark_color><form action=$MysqlTool::start_page METHOD=POST><td colspan=3>$MysqlTool::font<font color=white>";
    foreach( $q->param ) { print $q->hidden( -name => $_ ); }
    if( $q->param('_.edit._') ) {
        print "Editing record in table " . $q->param('_.table._') . " where " . join(' AND ', map("$_ = " . $dbh->quote($q->param($_)), split(/,/, $q->param('_.pkey._'))));
    } else {
        print "New record in table " . $q->param('_.table._');
    }
    print "</font></td></tr>";
    
    print "<tr><td colspan=3>$MysqlTool::font<font color=red>Remember to check the box next to the fields you are updating.</font></font></td></tr>";
    
    my $num = 0;
    foreach(0 .. scalar(@$fields) - 1) {
        next if( $pkeys->[$_] );
    
        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td valign=top>$MysqlTool::font<input type=checkbox name='_.fields._' value='$fields->[$_]'></font></td>";
        print "<td nowrap align=right valign=top>$MysqlTool::font", "$fields->[$_]</font></td>";
        print "<td width=100%>$MysqlTool::font";
        
        if( $lengths->[$_] =~ /^enum(.+?)$/i ) {
            my $enum = $1;
            $enum =~ s/''/\\'/g;
            print $q->popup_menu( -name => $fields->[$_], -values => [ eval($enum) ], -default => $record->[$_], -onFocus => "document.forms[0]['_.fields._'][$num] == null ? document.forms[0]['_.fields._'].checked = true : document.forms[0]['_.fields._'][$num].checked = true;");
        } elsif( $lengths->[$_] =~ /^set(.+?)$/i ) {
            my $set = $1;
            $set =~ s/''/\\'/g;
            print $q->checkbox_group( -name => $fields->[$_], -values => [ eval($set) ], -default => [ split(/,/, $record->[$_]) ], -onClick => "document.forms[0]['_.fields._'][$num] == null ? document.forms[0]['_.fields._'].checked = true : document.forms[0]['_.fields._'][$num].checked = true;");
        } elsif( $lengths->[$_] >= 255 ) {
            print $q->textarea( -name => $fields->[$_], cols => 60, rows => 4, -value => $record->[$_], -onFocus => "document.forms[0]['_.fields._'][$num] == null ? document.forms[0]['_.fields._'].checked = true : document.forms[0]['_.fields._'][$num].checked = true;");
        } elsif( $lengths->[$_] > 60 ) {
            print $q->textfield( -name => $fields->[$_], -size => 60, -maxlength => $lengths->[$_], -value => $record->[$_], -onFocus => "document.forms[0]['_.fields._'][$num] == null ? document.forms[0]['_.fields._'].checked = true : document.forms[0]['_.fields._'][$num].checked = true;");
        } else {
            print $q->textfield( -name => $fields->[$_], -size => $lengths->[$_], -maxlength => $lengths->[$_], -value => $record->[$_], -onFocus => "document.forms[0]['_.fields._'][$num] == null ? document.forms[0]['_.fields._'].checked = true : document.forms[0]['_.fields._'][$num].checked = true;");
        }
        print "</font></td>";
        print "</tr>";

        $num++;
    }
    
    print "<tr bgcolor=$MysqlTool::dark_grey><td colspan=3 align=center>$MysqlTool::font", $q->submit( -name => '_.Save._', -value => 'Save'), $q->submit( -name => '_.Cancel._', -value => 'Cancel'), "</font></td></tr>";
    print "</table>";

    return 1;
}

sub save_record {
    my $self = shift;
    my $database = shift;

    my $q = $self->{'CGI'};
    my $dbh = $database->{'dbh'};
    $dbh->do("use $database->{db}");

    my $sth = $dbh->prepare("desc " . $q->param('_.table._'));
    
    unless( $sth->execute ) {
        print "<center>$MysqlTool::font<font color=red>" . $dbh->errstr . "</font></center><br>";
        $sth->finish;
        return 0;
    }
    
    my %fields = map { $_, 1 } $q->param('_.fields._');

    return unless %fields;

    my(@fields, @values, $sql);

    if( $q->param('_.edit._') ) {
        while( my $ary = $sth->fetch ) {
            next if( $ary->[0] eq $q->param('_.pkey._') );
            next unless $fields{$ary->[0]};

            push(@fields, $ary->[0]);
            push(@values, "$ary->[0] = " . $dbh->quote(join(',', $q->param($ary->[0]))));
        }
        $sql = "UPDATE " . $q->param('_.table._') . " SET " . join(',', @values) . " WHERE " . join(' AND ', map("$_ = " . $dbh->quote($q->param($_)), split(/,/, $q->param('_.pkey._'))));
    } else {
        while( my $ary = $sth->fetch ) {
            next unless $fields{$ary->[0]};

            push(@fields, $ary->[0]);
            push(@values, $dbh->quote(join(',', $q->param($ary->[0]))));
        }

        $sql = "INSERT INTO " . $q->param('_.table._') . "(" . join(',', @fields) . ") VALUES(" . join(',', @values) . ")";
    }
    $sth->finish;

    #warn "$sql\n";
    unless( $dbh->do($sql) ) {
        print "<center>$MysqlTool::font<font color=red>" . $dbh->errstr . "</font></center><br>";
        return 0;
    }

    return 1;
}

1;
