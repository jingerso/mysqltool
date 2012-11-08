###############################################################################
# Server.pm 
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

package MysqlTool::Server;

use strict;

@MysqlTool::Server::ISA = qw(MysqlTool);

sub display {
    my $self = shift;

    my $q = $self->{'CGI'};
    
    my $reload_nav;

    my $server = $self->servers($q->param('_.server_id._'));
    my $dbh = $server->{'dbh'};

	unless ($dbh) {
		print "<center>$MysqlTool::font<font color=red>Error: Database connection failed. Please check your \$MysqlTool::servers configuration.</font></center>\n";
		return;
	}

    $dbh->do("use mysql");

    
    print "<table cellpadding=0 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::light_grey><td><table cellpadding=0 cellspacing=0 border=0 width=100%><tr>";
    print "<td><img src=$MysqlTool::image_dir/dirtree_elbow.gif border=0></td>";
    print "<td width=19><img src=$MysqlTool::image_dir/server2.gif border=0 width=19 height=16></td>";
    print "<td nowrap>$MysqlTool::font<b>$server->{'server'}:$server->{'port'}</b></font></td>";

    print "<td align=right width=100%>$MysqlTool::font";
    my @server_options;

    if( $server->{'admin_mode'} ) {
        $q->param('grants_sortby', '') unless $q->param('grants_sortby');
        push(@server_options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.in_flush._=1&grants_sortby=" . $q->param('grants_sortby') . " target=body>Execute \"Flush\" Statement</a>");
        push(@server_options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&grants_sortby=" . $q->param('grants_sortby') . "#GRANTS target=body>Users</a>");
        push(@server_options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&grants_sortby=" . $q->param('grants_sortby') . "#STATUS target=body>Server Status</a>");
        push(@server_options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&grants_sortby=" . $q->param('grants_sortby') . "#PROCESS target=body>Process List</a>");
        push(@server_options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&grants_sortby=" . $q->param('grants_sortby') . "#VARIABLES target=body>Server Variables</a>");
    }

    print join(' | ', @server_options);

    print "</font></td></tr>";

    print "</tr>";
    print "</table></td></tr></table>";

    if( $q->param('_.new_db._') ) {
        if( $q->param('Save') ) {
            my $rv = $self->new_db();
            if( $rv ) {
                print "<center>$MysqlTool::font<font color=red>$rv</font></font></center>";
                $self->display_new_db();

            } else {
                $reload_nav = 1;
            }
        } elsif( $q->param('Cancel') ) {

        } else {
            $self->display_new_db();
        }
    }
    
    if( $q->param('drop_db') ) {
        if( $server->{'admin_mode'} ) {
            unless( $dbh->do("DROP DATABASE " . $server->{'databases'}->{ $q->param('drop_db') }->{'db'}) ) {
                print "<center>$MysqlTool::font<font color=red>" . $dbh->errstr . "</font></font></center>";
            }
        } else {
            $self->session_dbh()->do("DELETE FROM user_servers WHERE server_id = " . $q->param('delete_server') . " AND user_id = $self->{'user_id'}");
        }
        $reload_nav = 1;
    }
    
    if( $reload_nav ) {
        $server = $self->servers($q->param('_.server_id._'), 0, 1);
        $dbh = $server->{'dbh'};
        $dbh->do("use mysql");
        
        print "<script language='JavaScript'>";
        print "window.parent.nav.location = window.parent.nav.location;";
        print "</script>";
    }
    
    $self->display_flush($server) if( $q->param('_.in_flush._') );

    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::dark_grey><td><table cellpadding=0 cellspacing=0 border=0 width=100%><tr>";
    print "<td>$MysqlTool::font<b>Databases</b></td>";
    print "<td align=right width=100%>$MysqlTool::font";

    if( $server->{'admin_mode'} ) {
        print "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.new_db._=1&grants_sortby=" . $q->param('grants_sortby') . ">Create Database</a>";
    }

    print "</font></td></tr>";
    print "</table></td></tr></table>";

    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
    if( %$server ) {
        
        print "<tr bgcolor=$MysqlTool::dark_grey>";
        print "<td align=center width=100%>$MysqlTool::font", "database</font></td>";
        if( $server->{'admin_mode'} ) {
            print "<td align=center>$MysqlTool::font", "drop</font></td>";
        }
        print "</tr>";
        
        my $x;
        foreach( sort { $a <=> $b } keys %{ $server->{'databases'} } ) {
            my $database = $server->{'databases'}->{$_};
            
            print "<tr bgcolor=" . ( $x++ % 2 == 0 ? $MysqlTool::light_grey : 'white' ) . ">";

            if( $database->{'status'} eq 'OK' ) {
                print "<td width=100%><table cellpadding=0 cellspacing=0 border=0><tr><td><img src=$MysqlTool::image_dir/db.gif></td><td>$MysqlTool::font<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.db_id._=$database->{ID}&_.in_db._=1>$database->{'db'}</a></font></td></tr></table></td>";
            } else {
                print "<td width=100%><table cellpadding=0 cellspacing=0 border=0><tr><td><img src=$MysqlTool::image_dir/db.gif></td><td>$MysqlTool::font$database->{'db'}</font></td></tr></table></td>";
            }

            if( $server->{'admin_mode'} ) {
                print "<td align=center><a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&drop_db=$database->{ID} onClick=\"return confirm('Are you sure you want to " . ( $server->{'admin_mode'} ? 'drop' : 'un-register' ) . " database: $database->{db}?');\"><img src=$MysqlTool::image_dir/trash.gif border=0></a></td>";
            }
            print "</tr>";
        }
    }
    print "</table>";
    
    
    $self->display_grants();
    
    $self->display_status();

    $self->display_processes() if( $server->{'admin_mode'} );
        
    $self->display_variables();    
}

sub new_db {
    my $self = shift;

    my $q = $self->{'CGI'};
    my $server = $self->servers($q->param('_.server_id._'));
    my $dbh = $server->{'dbh'};

    if( $server->{'admin_mode'} ) {
        return "Database name cannot contain '/' or '.' characters"
            if $q->param('db_name')=~/[\/\.]/;
        $dbh->do("CREATE DATABASE " . $q->param('db_name')) or return $dbh->errstr;
    }

    return 0;
}

sub display_new_db {
    my $self = shift;

    my $q = $self->{'CGI'};
    my $server = $self->servers($q->param('_.server_id._'));

    if( $server->{'admin_mode'} ) {
        print "<table cellpadding=2 cellspacing=2 border=0 width=100%>", $q->startform( -action => $MysqlTool::start_page, -method => 'POST' );

        print $q->hidden( -name => '_.in_main._' );
        print $q->hidden( -name => '_.server_id._' );
        print $q->hidden( -name => '_.new_db._' );
        print $q->hidden( -name => 'grants_sortby' );

        print "<tr bgcolor=$MysqlTool::dark_color><td colspan=2>$MysqlTool::font<font color=white>Create Database</font></font></td></tr>";
        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td align=right>$MysqlTool::font", "Name:</font></td>";
        print "<td width=100%>$MysqlTool::font", $q->textfield( -name => 'db_name', -size => 40, -maxlength => 64 ), "</font></td>";
        print "</tr>";
        print "<tr bgcolor=$MysqlTool::dark_grey><td align=center colspan=2>$MysqlTool::font<font color=$MysqlTool::dark_color>", $q->submit('Save'), $q->submit('Cancel'), "</font></font></td></tr>";
        print "</table>";
        print $q->endform;
    }
}

sub display_grants {
    my $self = shift;

    my $q = $self->{'CGI'};
    
    my $server = $self->servers($q->param('_.server_id._'));
    my $dbh = $server->{'dbh'};

    if( $server->{'admin_mode'} ) {
        print "<a name=GRANTS><hr>";
        
        if( $q->param('edit_server_grant') ) {
            if( $q->param('Save') ) {
                my $rv = $self->edit_server_grant;

                if( $rv ) {
                    print "<center>$MysqlTool::font<font color=red>$rv</font></font></center>";
                    $self->display_edit_server_grants();
                } 
            } elsif( $q->param('Cancel') ) {

            } else {
                $self->display_edit_server_grants();
            }
        }
        
        if( $q->param('delete') ) {
            foreach( qw(user db tables_priv columns_priv) ) {
                $dbh->do("DELETE FROM $_ WHERE User = " . $dbh->quote($q->param('user')) . " AND Host = " . $dbh->quote($q->param('host')));
            }

            $dbh->do("FLUSH PRIVILEGES");
        }
        
        print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
        print "<tr bgcolor=$MysqlTool::dark_grey><td><table cellpadding=0 cellspacing=0 border=0 width=100%><tr>";
        print "<td nowrap>$MysqlTool::font<b>Users</b></td>";
        print "<td align=right width=100%>$MysqlTool::font<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&edit_server_grant=1&grants_sortby=" . $q->param('grants_sortby') . "#EDITGRANT>New User</a></font></td>";
        print "</tr>";
        print "</table></td></tr></table>";
        
        my $grants_sortby = $q->param('grants_sortby') || 'User';
        
        my $sth = $dbh->prepare("SELECT * FROM user order by $grants_sortby");
        $sth->execute;
        
        my @columns = qw(User Host Password Select_priv Insert_priv Update_priv Delete_priv Create_priv Drop_priv Reload_priv Shutdown_priv Process_priv File_priv Grant_priv Index_priv Alter_priv);
        my %labels  = map { $_, (split(/_/, $_, 2))[0] } @columns;

        if( $sth->rows ) {
            print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
            print "<tr bgcolor=$MysqlTool::dark_grey>";
            foreach( @columns ) {
                if( $grants_sortby eq $_ ) {
                    print "<td bgcolor=$MysqlTool::dark_color align=center>$MysqlTool::font<font color=white>", "$labels{$_}</font></font></td>";
                } else {
                    print "<td align=center>$MysqlTool::font<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&grants_sortby=$_>$labels{$_}</a></font></td>";
                }
            }
            print "<td align=center>$MysqlTool::font", "delete</font></td>";
            print "</tr>";
            
            my $x;
            while( my $row = $sth->fetchrow_hashref ) {
                print "<tr bgcolor=" . ( $x++ % 2 == 0 ? $MysqlTool::light_grey : 'white' ) . ">";
                foreach( @columns ) {
                    if( $_ eq 'User' ) {
                        print "<td><table cellpadding=0 cellspacing=0 border=0><tr><td><a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&user=" . $q->escape($row->{User}) . "&host=" . $q->escape($row->{Host}) . "&edit_server_grant=1&grants_sortby=$grants_sortby#EDITGRANT><img src=$MysqlTool::image_dir/user2.gif border=0></a></td><td>$MysqlTool::font", "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&user=" . $q->escape($row->{User}) . "&host=" . $q->escape($row->{Host}) . "&edit_server_grant=1&grants_sortby=$grants_sortby#EDITGRANT>$row->{$_}</a></td></tr></table></td>";
                    } elsif( $_ eq 'Password' ) {
                        print "<td>$MysqlTool::font", ($row->{$_} ne '' ? '********' : '&nbsp;'), "</font></td>";
                    } else {
                        print "<td>$MysqlTool::font", ($row->{$_} ? $row->{$_} : '&nbsp;'), "</font></td>";
                    }
                }
                print "<td align=center><a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&user=" . $q->escape($row->{User}) . "&host=" . $q->escape($row->{Host}) . "&delete=1 onClick=\"return confirm('Are you sure you want to delete user: $row->{User}\@$row->{Host}?\\nThis user won\\'t have any access to the server after he is deleted.');\"><img src=$MysqlTool::image_dir/trash.gif border=0></a></td>";
                print "</tr>";
            }
            $sth->finish;
            print "</table>";
        }
    }
}

sub display_edit_server_grants {
    my $self = shift;

    my $q = $self->{'CGI'};
    my $server = $self->servers($q->param('_.server_id._'));
    my $dbh = $server->{'dbh'};
    $dbh->do("use mysql");
    
    my $data = {};
    
    if( $q->param('host') ) {
        my $sth = $dbh->prepare("SELECT * FROM user WHERE User = " . $dbh->quote($q->param('user')) . " AND Host = " . $dbh->quote($q->param('host')));
        $sth->execute();
        $data = $sth->fetchrow_hashref;
        $sth->finish;
    }
    
    print "<script language='JavaScript'>\n";
    print "function check_all(option) {\n";
    print "\tfor( i = 0; i < document.forms[0].Privileges1.length; i++ ) {\n";
    print "\t\tdocument.forms[0].Privileges1[i].checked = option;\n";
    print "\t}\n";
    print "\tfor( i = 0; i < document.forms[0].Privileges2.length; i++ ) {\n";
    print "\t\tdocument.forms[0].Privileges2[i].checked = option;\n";
    print "\t}\n";
    print "\tdocument.forms[0].Grant_priv.checked = option;\n";
    print "}\n";
    print "</script>\n";
    print "<A name=EDITGRANT>";
    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::dark_color>", $q->startform( -action => $MysqlTool::start_page, -method => 'POST' );
    print "<td colspan=2>$MysqlTool::font<font color=white>", ( %$data ? "Edit user: $data->{User}\@$data->{Host}" : "New User" ), "</font></font></td>";
    print "</tr>";
    
    print $q->hidden( -name => '_.in_main._' );
    print $q->hidden( -name => '_.server_id._' );
    print $q->hidden( -name => 'edit_server_grant' );
    print $q->hidden( -name => 'user' );
    print $q->hidden( -name => 'host' );
    print $q->hidden( -name => 'grants_sortby' );

    my @privileges1 = qw(Select_priv Insert_priv Update_priv Delete_priv Index_priv Alter_priv Create_priv);
    my @privileges2 = qw(Drop_priv References_priv Reload_priv Shutdown_priv Process_priv File_priv);

    unless( %$data ) {
        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td align=right nowrap>$MysqlTool::font", "User:</font></td>";
        print "<td width=100%>$MysqlTool::font", $q->textfield( -name => 'Username', -size => 16, -maxlength => 16, -default => $data->{User} ), "</font></td>";
        print "</tr>";
    
        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td align=right nowrap>$MysqlTool::font", "Host:</font></td>";
        print "<td width=100%>$MysqlTool::font", $q->textfield( -name => 'Host', -size => 60, -maxlength => 60, -default => $data->{Host} ), "</font></td>";
        print "</tr>";
    
        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td align=right nowrap>$MysqlTool::font", "Password:</font></td>";
        print "<td width=100%>$MysqlTool::font", $q->password_field( -name => 'Password', -size => 16), "</font></td>";
        print "</tr>";
        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td align=right nowrap>$MysqlTool::font", "Confirm Password:</font></td>";
        print "<td width=100%>$MysqlTool::font", $q->password_field( -name => 'Password2', -size => 16), "</font></td>";
        print "</tr>";

        $data = { map { $_, 'N' } (@privileges1, @privileges2, 'Grant_priv') };
    }

    print "<tr bgcolor=$MysqlTool::light_grey>";
    print "<td valign=top align=right nowrap>$MysqlTool::font", "Server Scope Privileges:<BR><BR>(<a href=\"javascript:void check_all(true);\">Check All</a>\n | <a href=\"javascript:void check_all(false);\">Un-check All</a>)</font></td>";
    print "<td width=100%>";
    print "<table cellpadding=2 cellspacing=2 border=0>";
    print "<tr>";
    print "<td>$MysqlTool::font", $q->checkbox_group( -name => 'Privileges1', -values => \@privileges1, -linebreak => 'true', -labels => { map { $_, (split(/_/, $_, 2))[0] } @privileges1 }, -default => [ grep { $data->{$_} eq 'Y' } @privileges1 ]), "</font></td>";
    print "<td>&nbsp; &nbsp; &nbsp; &nbsp;</td>";
    print "<td valign=top>$MysqlTool::font", $q->checkbox_group( -name => 'Privileges2', -values => \@privileges2, -linebreak => 'true', -labels => { map { $_, (split(/_/, $_, 2))[0] } @privileges2 }, -default => [ grep { $data->{$_} eq 'Y' } @privileges2 ]), "</font></td>";
    print "</tr></table></td>";
    print "</tr>";
    
    print "<tr bgcolor=$MysqlTool::light_grey>";
    print "<td align=right nowrap>$MysqlTool::font", "Grant Option:</font></td>";
    print "<td width=100%>$MysqlTool::font", $q->checkbox( -name => 'Grant_priv', -label => '', -value => 1, -checked => ( $data->{'Grant_priv'} eq 'Y' ? 1 : 0 ) ), "</font></td>";
    print "</tr>";

    if( $q->param('host') ) {
        print "<tr bgcolor=$MysqlTool::dark_grey><td colspan=2>$MysqlTool::font", "Change password</font></td></tr>";

        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td align=right nowrap>$MysqlTool::font", "New Password:</font></td>";
        print "<td width=100%>$MysqlTool::font", $q->password_field( -name => 'Password', -size => 16, -maxlength => 16 ), "</font></td>";
        print "</tr>";
        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td align=right nowrap>$MysqlTool::font", "Confirm New Password:</font></td>";
        print "<td width=100%>$MysqlTool::font", $q->password_field( -name => 'Password2', -size => 16, -maxlength => 16 ), "</font></td>";
        print "</tr>";
    }

    print "<tr bgcolor=$MysqlTool::dark_grey><td align=center colspan=2>$MysqlTool::font<font color=$MysqlTool::dark_color>", $q->submit('Save'), $q->submit('Cancel'), "</font></font></td></tr>";
    print "</table>";
    print $q->endform;
}

sub edit_server_grant {
    my $self = shift;

    my $q = $self->{'CGI'};
    my $server = $self->servers($q->param('_.server_id._'));
    my $dbh = $server->{'dbh'};
    
    my @priv = $q->param('Privileges1'); @priv = (@priv, $q->param('Privileges2'));
    unless( $q->param('host') ) {
        
        if( $q->param('Password') ne $q->param('Password2') ) {
            return "passwords don't match!";
        }
        
        unless( @priv ) {
            push(@priv, 'Usage_priv');
        }

        unless( $q->param('Host') ) {
            return "you must specify a Host!";
        }
        
        my $sql = "GRANT " . join(', ', map((split(/_/, $_, 2))[0], @priv)) . " ON *.* TO ";
        $sql .= ( $q->param('Username') ? "'".$q->param('Username')."'" : '""' ) . "\@";
        $sql .=  '"' . $q->param('Host') . '"' ;
        $sql .= " IDENTIFIED BY " . $dbh->quote($q->param('Password')) if( $q->param('Password') );
        $sql .= " WITH GRANT OPTION" if( $q->param('Grant_priv') );

        if( $dbh->do($sql) ) {
            return 0;
        } else {
            return $dbh->errstr;
        }
    } else {
        if( $q->param('Password') ) {
            if( $q->param('Password') ne $q->param('Password2') ) {
                return "passwords don't match!";
            }
            
            $dbh->do("UPDATE user SET Password = PASSWORD(" . $dbh->quote($q->param('Password')) . ") WHERE User = " . $dbh->quote($q->param('user')) . " AND Host = " . $dbh->quote($q->param('host')));
        }

        my @privileges = qw(Select_priv Insert_priv Update_priv Delete_priv Index_priv Alter_priv Create_priv Drop_priv References_priv Reload_priv Shutdown_priv Process_priv File_priv);

        my $sth = $dbh->prepare("SELECT * FROM user WHERE User = " . $dbh->quote($q->param('user')) . " AND Host = " . $dbh->quote($q->param('host')));
        $sth->execute();
        my $data = $sth->fetchrow_hashref;
        $sth->finish;

        my %grants = map { $_, 1 } grep { $data->{$_} eq 'Y' } @privileges;
        my %new_grants = map { $_, 1 } @priv;

        my(@grant, @revoke);
        foreach( @privileges ) {
            push(@grant, (split(/_/, $_, 2))[0])    if( $new_grants{$_} && !($grants{$_}) );
            push(@revoke, (split(/_/, $_, 2))[0])   if( $grants{$_} && !($new_grants{$_}) );
        }
        
        if( @grant ) {
            my $sql = "GRANT " . join(', ', @grant) . " ON *.* TO ";
            $sql .= ( $q->param('user') ? "'".$q->param('user')."'" : '""' ) . "\@";
            $sql .=  '"' . $q->param('host') . '"' ;
            $sql .= " WITH GRANT OPTION" if( $q->param('Grant_priv') );

            $dbh->do($sql);
        }

        if( @revoke ) {
            my $sql = "REVOKE " . join(', ', @revoke) . " ON *.* FROM ";
            $sql .= ( $q->param('user') ? $q->param('user') : '""' ) . "\@";
            $sql .= ($q->param('host') eq '%' ? '"' . $q->param('host') . '"' : $q->param('host'));

            $dbh->do($sql);
        }
        
        unless( $q->param('Grant_priv') ) {
            $dbh->do("UPDATE user SET Grant_priv = 'N' WHERE User = " . $dbh->quote($q->param('user')) . " AND Host = " . $dbh->quote($q->param('host'))); 
        }
        
        $dbh->do("FLUSH PRIVILEGES");
        return 0;
    }
}

sub display_flush {
    my $self = shift;
    my $server = shift;

    my $q = $self->{'CGI'};

    if( $q->param('Flush') ) {
        print "<center>$MysqlTool::font", "FLUSH command succeded!</font></center>";
        my @options = $q->param('options');

        $server->{'dbh'}->do("FLUSH " . join(',', @options)) if( @options );
        return;
    }

    return if( $q->param('Cancel') );
    
    my %options = (
        'HOSTS'         => 'Flushes the host cache.',
        'LOGS'          => 'Flushes the log files by closing and reopening them.',
        'PRIVILEGES'    => 'Reloads the grant tables.',
        'STATUS'        => 'Reinitializes the status variables',
        'TABLES'        => 'Closes any open tables in the table cache'
    );
    print $q->startform( -action => $MysqlTool::startpage );
    print $q->hidden( -name => '_.in_main._' );
    print $q->hidden( -name => '_.server_id._' );
    print $q->hidden( -name => '_.in_flush._' );
    print $q->hidden( -name => 'grants_sortby' );

    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::dark_color>";
    print "<td colspan=3>$MysqlTool::font<font color=white>Execute \"FLUSH\" Statement</font></td>";
    print "</tr>";
    print "<tr bgcolor=$MysqlTool::dark_grey>";
    print "<td align=center>$MysqlTool::font", "&nbsp;</font></td>";
    print "<td align=center>$MysqlTool::font", "Option</font></td>";
    print "<td align=center>$MysqlTool::font", "Desctiption</font></td>";
    print "</tr>";
    
    my $x = 0;
    foreach( keys %options ) {
        print "<tr bgcolor=", ( $x++ % 2 == 0 ? $MysqlTool::light_grey : 'white' ), ">";
        print "<td align=center>$MysqlTool::font<input type=checkbox name=options value=$_></font></td>";
        print "<td>$MysqlTool::font", "$_</font></td>";
        print "<td>$MysqlTool::font", "$options{$_}</font></td>";
        print "</tr>";
    }
    
    print "<tr bgcolor=$MysqlTool::dark_grey><td align=center colspan=3>$MysqlTool::font<font color=$MysqlTool::dark_color>", $q->submit('Flush'), $q->submit('Cancel'), "</font></font></td></tr>";
    print "</table></form>";
}

sub display_status {
    my $self = shift;

    my $q = $self->{'CGI'};
    my $server = $self->servers($q->param('_.server_id._'));
    my $dbh = $server->{'dbh'};

    my $x = 1;
    print "<a name=STATUS><hr>";
    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::dark_grey><td>$MysqlTool::font", "<b>Server Status</b></font></td></tr>";
    print "<tr><td>";
    print "<table cellpadding=0 cellspacing=0 border=0 width=100%>";
    print "<tr><td valign=top>";
    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
    my $sth = $dbh->prepare("show status");
    $sth->execute;
    while( my $row = $sth->fetch ) {
        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td>$MysqlTool::font", "$row->[0]:</font></td>";
        print "<td width=100%>$MysqlTool::font", "$row->[1]</font></td>";
        print "</tr>";

        if( $x++ % 13 == 0 ) {
            print "</table></td><td valign=top><table cellpadding=2 cellspacing=2 border=0 width=100%>";
        }
    }
    $sth->finish;
    print "</table>";
    print "</td></tr></table>";
    print "</td></tr></table>";
}

sub display_processes {
    my $self = shift;

    my $q = $self->{'CGI'};
    my $server = $self->servers($q->param('_.server_id._'));
    my $dbh = $server->{'dbh'};

    print "<a name=PROCESS><hr>";

    if( $q->param('kill') && ( $self->compare_version($server->{'mysql_version'}, '3.22.9') ) ) {
        $dbh->do("KILL " . $q->param('kill'));
        print "<center>$MysqlTool::font<font color=red>Process killed!</font></font></center>";
    }

    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::dark_grey><td>$MysqlTool::font<b>Process List</b></font></td></tr>";
    print "</table>";
    
    my $sth = $dbh->prepare("SHOW PROCESSLIST");
    $sth->execute;
    
    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::dark_grey>";
    foreach(@{ $sth->{NAME} }) {
        print "<td align=center>$MysqlTool::font", "$_</font></td>";
    }
    print "<td align=center>$MysqlTool::font", "kill</td>" if( $self->compare_version($server->{'mysql_version'}, '3.22.9') );
    print "</tr>";

    my $x = 1;
    while( my $row = $sth->fetch ) {
        print "<tr bgcolor=" . ($x++ % 2 == 0 ? $MysqlTool::light_grey : 'white') . ">";
        foreach( @$row ) {
            print "<td>$MysqlTool::font", ($_ ? $_ : '&nbsp;'), "</font></td>";
        }
        print "<td align=center><a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&kill=$row->[0]&grants_sortby=" . $q->param('grants_sortby') . " onClick=\"return confirm('Are you sure you want to kill process id: $row->[0]?');\"><img src=$MysqlTool::image_dir/trash.gif border=0></a></td>" if( $self->compare_version($server->{'mysql_version'}, '3.22.9') );
        print "</tr>";
    }
    $sth->finish;

    print "</table>";
}

sub display_variables {
    my $self = shift;

    my $q = $self->{'CGI'};
    my $server = $self->servers($q->param('_.server_id._'));
    my $dbh = $server->{'dbh'};

    print "<a name=VARIABLES><hr>";

    my $sth = $dbh->prepare("SHOW VARIABLES");
    $sth->execute;
    
    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::dark_grey><td colspan=2>$MysqlTool::font<b>Server Variables</b> (mysqld variables that can be set with the --set-variable option)</font></td></tr>";
    print "<tr bgcolor=$MysqlTool::dark_grey>";
    print "<td align=center>$MysqlTool::font", "variable</font></td>";
    print "<td align=center>$MysqlTool::font", "value</font></td>";
    print "</tr>";

    my $x = 0;
    while( my $row = $sth->fetch ) {
        print "<tr bgcolor=", ( $x++ % 2 == 0 ? $MysqlTool::light_grey : 'white' ), ">";
        print "<td>$MysqlTool::font", "$row->[0]</font></td>";
        print "<td>$MysqlTool::font", "$row->[1]</font></td>";
        print "</tr>";
    }
    
    print "</table>";
    
    $sth->finish;
}

1;
