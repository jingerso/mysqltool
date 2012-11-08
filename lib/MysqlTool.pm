###############################################################################
# MysqlTool.pm 
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

package MysqlTool;

use strict;
use Data::Dumper;
use Apache2::Const;
use Apache2::Log;

$MysqlTool::VERSION = '0.95';

sub new { bless $_[1], $_[0] }

sub fail {
    my ($r, $status, $message) = @_;
    $r->log_error($message, $r->filename);
    return $status;
}

sub handler {
    my $r = shift;
    
    if (ref($r) eq "Apache") { 
        # so images will show when <Location /mysqltool>\nSet-Handler MysqlTool ...
    	return -1 if $r->content_type && $r->content_type !~ m|^text/|i;
    }

    if( eval "use CGI" ) {
        die "failed to load CGI module -- $@\n";
    }

    if( eval "use Template" ) {
        die "failed to load Template module -- $@\n";
    }

    #DBI->trace(1);

    my $q = CGI->new();
    my $tt = Template->new({ 
      INCLUDE_PATH => '/home/joe/mysqltool/lib/templates',
      #PRE_PROCESS => 'config',
      OUTPUT => $r
    });

    my $self = MysqlTool->new({ CGI => $q, TT => $tt, Apache => $r });

    $self->set_defaults();
    #$self->load_modules();
   
    if( $self->manage_session() ) {
        return $self->display();
    } else {
        return $self->display_login();
    }
}

sub TODO_load_modules {
    my $self = shift;
    my @req_modules = qw(MysqlTool::Nav MysqlTool::Servers MysqlTool::Server MysqlTool::Db MysqlTool::Table MysqlTool::Field MysqlTool::Dump MysqlTool::Query);
    if( $ENV{MOD_PERL} ) {
        push(@req_modules, "Apache::DBI");
    } else {
        push(@req_modules, "DBI");
    }
    if( $MysqlTool::mode eq 'MULTI USER' ) {
        push(@req_modules, "Crypt::Blowfish");
    }
    foreach my $module (@req_modules) {
        unless( eval "require $module" ) {
            die "required module $module failed to load -- $@!\n";
        }
    }
}

sub display {
    my $self = shift;

    my $q = $self->{'CGI'};
    
    if( $q->param('_.in_nav._') ) {
        MysqlTool::Nav->new($self)->display();
    } elsif( $q->param('_.in_main._') ) {
        $self->display_main();
    } else {
        print "<HEAD><TITLE>$MysqlTool::title</TITLE></HEAD>";
        print '<FRAMESET cols=250,* FRAMEBORDER=1 FRAMESPACING=0>';
        print '<frame name=nav src=' . $MysqlTool::start_page . '?_.in_nav._=1 marginwidth=0 marginheight=0 target="main" scrolling="auto">';
        print '<frame name=body src=' . $MysqlTool::start_page . '?_.in_main._=1 marginwidth=0 marginheight=0>';
        print '</FRAMESET>';
    }

    return $Apache2::Const::OK;
}

sub servers {
    my $self = shift;
    
    my $server_id = shift;
    my $database_id = shift;
    my $no_cache = shift;
    
    my $x = 1;
    
    if( !(defined($self->{'servers'})) or $no_cache ) {
        #delete( $self->{'servers'} );

        if( $MysqlTool::mode eq 'SINGLE USER' ) {

            foreach my $server_id ( keys %MysqlTool::servers ) {
                my $server = $MysqlTool::servers{ $server_id };
                
                $self->{'servers'}->{ $server_id } = { %$server };
                $self->{'servers'}->{ $server_id }->{'ID'} = $server_id;
                $self->{'servers'}->{ $server_id }->{'count'} = $x++;
                
                my $y = 1;

                if( exists($server->{'admin_user'}) && exists($server->{'admin_password'}) ) {

                    my $dbh =  DBI->connect("DBI:mysql:database=mysql;host=$server->{'server'};port=$server->{'port'}", $server->{admin_user}, $server->{admin_password}, { PrintError => 0 });
                    
                    if( $dbh ) {
                        $self->{'servers'}->{ $server_id }->{'dbh'} = $dbh;
                        
                        my $sth = $dbh->prepare("SELECT VERSION()");
                        $sth->execute;
                        ($self->{'servers'}->{ $server_id }->{'mysql_version'} = $sth->fetch->[0]) =~ s/-.*$//;
                        #$self->{'servers'}->{ $server_id }->{'mysql_version'} = '3.22.0';
                        $sth->finish;
                        
                        $sth = $dbh->prepare("show databases");
                        $sth->execute;
                        while( my $row = $sth->fetch ) {
                            $self->{'servers'}->{ $server_id }->{'databases'}->{ $y }->{'ID'} = $y;
                            $self->{'servers'}->{ $server_id }->{'databases'}->{ $y }->{'dbh'} = $dbh;
                            $self->{'servers'}->{ $server_id }->{'databases'}->{ $y }->{'status'} = 'OK';
                            $self->{'servers'}->{ $server_id }->{'databases'}->{ $y }->{'db'} = $row->[0];
                            $self->{'servers'}->{ $server_id }->{'databases'}->{ $y }->{'count'} = $y;
                            $self->{'servers'}->{ $server_id }->{'databases'}->{ $y }->{'admin_mode'} = 1;
                            $self->{'servers'}->{ $server_id }->{'databases'}->{ $y }->{'mysql_version'} = $self->{'servers'}->{ $server_id }->{'mysql_version'};

                            $y++;
                        }
                        $sth->finish;

                        $self->{'servers'}->{ $server_id }->{'status'} = 'OK';
                        $self->{'servers'}->{ $server_id }->{'admin_mode'} = 1;
                    } else {
                        $self->{'servers'}->{ $server_id }->{'status'} = "<font color=red>$DBI::errstr</font>";
                    }

                } else {
                    $self->{'servers'}->{ $server_id }->{'status'} = 'OK';
                
                    foreach my $db_id ( keys %{ $server->{'databases'} } ) {
                        my $db = $server->{'databases'}->{ $db_id };
                    
                        my $dbh = DBI->connect("DBI:mysql:database=$db->{db}:host=$server->{'server'}:port=$server->{'port'}", $db->{username}, $db->{password}, { PrintError => 0 });

                        $self->{'servers'}->{ $server_id }->{'databases'}->{ $db_id } = $db;
                        $self->{'servers'}->{ $server_id }->{'databases'}->{ $db_id }->{'ID'} = $db_id;
                        $self->{'servers'}->{ $server_id }->{'databases'}->{ $db_id }->{'count'} = $y++;
                
                        if( $dbh ) {
                            $self->{'servers'}->{ $server_id }->{'databases'}->{ $db_id }->{'dbh'} = $dbh;
                            $self->{'servers'}->{ $server_id }->{'databases'}->{ $db_id }->{'status'} = 'OK';

                            unless( defined($self->{'servers'}->{ $server_id }->{'mysql_version'}) ) {
                                my $sth = $dbh->prepare("SELECT VERSION()");
                                $sth->execute;
                                ($self->{'servers'}->{ $server_id }->{'mysql_version'} = $sth->fetch->[0]) =~ s/-.*$//;
                                $sth->finish;
                            }

                            $self->{'servers'}->{ $server_id }->{'databases'}->{ $db_id }->{'mysql_version'} = $self->{'servers'}->{ $server_id }->{'mysql_version'};
                            $self->{'servers'}->{ $server_id }->{'dbh'} = $dbh;
                        } else {
                            $self->{'servers'}->{ $server_id }->{'databases'}->{ $db_id }->{'status'} = "<font color=red>$DBI::errstr</font>";
                        }
                    }
                }
                
                foreach( keys %{ $server->{'databases'} } ) {
                    if( $server->{'databases'}->{$_}->{'count'} == $y - 1 ) {
                        $server->{'databases'}->{$_}->{'Last'} = 1;
                    }
                }
            }
        } else {
            #Carp->cluck();
            #warn Data::Dumper->Dumper($self->{'conn_params'});
            my $server_id = 1;
            $self->{'servers'}->{ $server_id }->{'ID'} = 1;
            $self->{'servers'}->{ $server_id }->{'count'} = 1;
            $self->{'servers'}->{ $server_id }->{'server'} = $self->{'conn_params'}->{'server'};
            $self->{'servers'}->{ $server_id }->{'port'} = $self->{'conn_params'}->{'port'};

            my $y = 1;
            if( $self->{'conn_params'}->{'is_admin'} ) {
                $self->{'servers'}->{ $server_id }->{'admin_user'} = $self->{'conn_params'}->{'user'};
                $self->{'servers'}->{ $server_id }->{'admin_password'} = $self->{'conn_params'}->{'pass'};
            
                my $dbh =  DBI->connect("DBI:mysql:database=mysql;host=$self->{'conn_params'}->{'server'};port=$self->{'conn_params'}->{'port'}", $self->{'conn_params'}->{user}, $self->{'conn_params'}->{pass}, { PrintError => 0 });
                    
                if( $dbh ) {
                    $self->{'servers'}->{ $server_id }->{'dbh'} = $dbh;
                        
                    my $sth = $dbh->prepare("SELECT VERSION()");
                    $sth->execute;
                    ($self->{'servers'}->{ $server_id }->{'mysql_version'} = $sth->fetch->[0]) =~ s/-.*$//;
                    #$self->{'servers'}->{ $server_id }->{'mysql_version'} = '3.22.0';
                    $sth->finish;
                        
                    $sth = $dbh->prepare("show databases");
                    $sth->execute;
                    while( my $row = $sth->fetch ) {
                        $self->{'servers'}->{ $server_id }->{'databases'}->{ $y }->{'ID'} = $y;
                        $self->{'servers'}->{ $server_id }->{'databases'}->{ $y }->{'dbh'} = $dbh;
                        $self->{'servers'}->{ $server_id }->{'databases'}->{ $y }->{'status'} = 'OK';
                        $self->{'servers'}->{ $server_id }->{'databases'}->{ $y }->{'db'} = $row->[0];
                        $self->{'servers'}->{ $server_id }->{'databases'}->{ $y }->{'count'} = $y;
                        $self->{'servers'}->{ $server_id }->{'databases'}->{ $y }->{'admin_mode'} = 1;
                        $self->{'servers'}->{ $server_id }->{'databases'}->{ $y }->{'mysql_version'} = $self->{'servers'}->{ $server_id }->{'mysql_version'};

                        $y++;
                    }
                    $sth->finish;

                    $self->{'servers'}->{ $server_id }->{'status'} = 'OK';
                    $self->{'servers'}->{ $server_id }->{'admin_mode'} = 1;
                } else {
                   $self->{'servers'}->{ $server_id }->{'status'} = "<font color=red>$DBI::errstr</font>";
                }
            } else {
                my $dbh =  DBI->connect("DBI:mysql:database=$self->{'conn_params'}->{'db'};host=$self->{'conn_params'}->{'server'};port=$self->{'conn_params'}->{'port'}", $self->{'conn_params'}->{user}, $self->{'conn_params'}->{pass}, { PrintError => 0 });
                
                if( $dbh ) {
                    $self->{'servers'}->{ $server_id }->{'dbh'} = $dbh;
                        
                    my $sth = $dbh->prepare("SELECT VERSION()");
                    $sth->execute;
                    ($self->{'servers'}->{ $server_id }->{'mysql_version'} = $sth->fetch->[0]) =~ s/-.*$//;
                    $sth->finish;
                        
                    $self->{'servers'}->{ $server_id }->{'databases'}->{ $y }->{'ID'} = $y;
                    $self->{'servers'}->{ $server_id }->{'databases'}->{ $y }->{'dbh'} = $dbh;
                    $self->{'servers'}->{ $server_id }->{'databases'}->{ $y }->{'status'} = 'OK';
                    $self->{'servers'}->{ $server_id }->{'databases'}->{ $y }->{'db'} = $self->{'conn_params'}->{'db'};
                    $self->{'servers'}->{ $server_id }->{'databases'}->{ $y }->{'count'} = $y;
                    $self->{'servers'}->{ $server_id }->{'databases'}->{ $y }->{'mysql_version'} = $self->{'servers'}->{ $server_id }->{'mysql_version'};
                    $y++;

                    $self->{'servers'}->{ $server_id }->{'status'} = 'OK';
                } else {
                    $self->{'servers'}->{ $server_id }->{'status'} = "<font color=red>$DBI::errstr</font>";
                }
            }
            
            foreach( keys %{ $self->{'servers'}->{ $server_id }->{'databases'} } ) {
                if( $self->{'servers'}->{ $server_id }->{'databases'}->{$_}->{'count'} == $y - 1 ) {
                    $self->{'servers'}->{ $server_id }->{'databases'}->{$_}->{'Last'} = 1;
                }
            }
            $x++;
            #warn Data::Dumper->Dumper($self->{'servers'});
        }

        foreach( keys %{ $self->{'servers'} } ) { 
            if( $self->{'servers'}->{$_}->{'count'} == $x - 1 ) {
                $self->{'servers'}->{$_}->{'Last'} = 1;
            }
        }
    }
    
    return $server_id ? ( $database_id ? $self->{'servers'}->{$server_id}->{'databases'}->{$database_id} : $self->{'servers'}->{$server_id} ) : $self->{'servers'};
}

sub user {
    my $self = shift;

    my $q = $self->{'CGI'};

    if( $MysqlTool::mode eq 'SINGLE USER' ) {
        my $server = $self->servers($q->param('_.server_id._'));
        my $dbh = $server->{'dbh'};
        
        my $sth = $dbh->prepare("SELECT USER()");
        $sth->execute();
        my $user = $sth->fetch->[0];
        $sth->finish;

    } else {
        return $self->{'username'};
    }
}

sub display_main {
    my $self = shift;

    my $q = $self->{'CGI'};
    my $c = $self->{'conn_params'};

    my $server = $self->servers($q->param('_.server_id._'));
    my $database = $q->param('_.db_id._') ? $server->{'databases'}->{ $q->param('_.db_id._') } : {};

    my $dbh = $server->{'dbh'};
    my $query_obj = MysqlTool::Query->new($self);
    
    if( $q->param('_.sql_frames._') ) {
        my $result_src = "$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.db_id._=$database->{ID}&_.in_result._=1";
        $result_src .= "&_.Execute._=Execute&_.statement._=" . $q->escape("SELECT * FROM " . $q->param('_.table._')) . "&_.start._=1&_.limit._=100&_.table._=" . $q->param('_.table._') if( $q->param('_.browse._') );
        $result_src .= "&_.new_record._=1" if( $q->param('_.new_record._') );
        
        my $rows = $MysqlTool::query_frame_height || 300;

        print "<HEAD><TITLE>$MysqlTool::title</TITLE></HEAD>";
        print "<FRAMESET rows=$rows,* FRAMEBORDER=1 FRAMESPACING=0>";
        print '<frame name=statement src=' . $MysqlTool::start_page . "?_.in_main._=1&_.server_id._=$server->{ID}&_.db_id._=$database->{ID}&_.in_statement._=1&_.table._=" . $q->param('_.table._') . ' marginwidth=0 marginheight=0 target="main" scrolling="auto">';
        print "<frame name=result src=$result_src marginwidth=0 marginheight=0>";
        print '</FRAMESET>';
        return;
    }

    print $q->start_html(-bgcolor => 'white', -link => $MysqlTool::dark_color, -alink => $MysqlTool::dark_color, -vlink => $MysqlTool::dark_color );
    
    if( $q->param('_.in_result._') ) {
        if( ($q->param('_.edit._') || $q->param('_.new_record._')) && !( $q->param('_.Cancel._') || $q->param('_.Save._') ) ) {
            return $query_obj->display_edit_record($database);
        } else {
            $query_obj->save_record($database) if $q->param('_.Save._');
            return $query_obj->display_result_frame($database);
        }
    }

   print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
   if( $MysqlTool::mode eq 'MULTI USER' ) {
        print "<tr bgcolor=$MysqlTool::dark_grey><td><table cellpadding=0 cellspacing=0 border=0 width=100%><tr>";
        print "<td>$MysqlTool::font", "<b><a href=https://github.com/jingerso/mysqltool target=_top>MysqlTool</a></b> v$MysqlTool::VERSION</font></font></td>";
        print "<td align=right>$MysqlTool::font", "<a href=$MysqlTool::start_page?_..logout.._=1 target=_top><b>logout</b></a></font></td>"; 
        print "</tr>";
    } else {
        print "<tr bgcolor=$MysqlTool::dark_grey><td><table cellpadding=0 cellspacing=0 border=0 width=100%><tr>";
        print "<td>$MysqlTool::font", "<b><a href=https://github.com/jingerso/mysqltool target=_top>MysqlTool</a></b></font></font></td>";
        print "<td align=right>$MysqlTool::font", "Version $MysqlTool::VERSION</font></td>"; 
        print "</tr>";
    }
    print "<tr><td colspan=2 height=2><img src=$MysqlTool::image_dir/transparent.gif width=1 height=2></td></tr>";
    print "</table></td></tr>";
    print "</table>";

    unless( $q->param('_.server_id._') ) {
        MysqlTool::Servers->new($self)->display();
        return;
    }
    
    print "<table cellpadding=0 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::light_grey><td><table cellpadding=0 cellspacing=0 border=0 width=100%><tr>";
    print "<td width=19><img src=$MysqlTool::image_dir/servers3.gif border=0 width=19 height=16></td>";
    print "<td nowrap width=100%>$MysqlTool::font<a href=$MysqlTool::start_page?_.in_main._=1 target=body>Mysql Servers</a></font></td>";
    print "<td align=right width=100%>$MysqlTool::font", "&nbsp;</font></td></tr>";
    print "</table></td></tr></table>";
    
    unless( $q->param('_.db_id._') ) {
        MysqlTool::Server->new($self)->display();
        return;
    }
    
    print "<table cellpadding=0 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::light_grey><td><table cellpadding=0 cellspacing=0 border=0 width=100%><tr>";
    print "<td><img src=$MysqlTool::image_dir/dirtree_elbow.gif border=0></td>";
    print "<td width=19><img src=$MysqlTool::image_dir/server2.gif border=0 width=19 height=16></td>";
    print "<td nowrap width=100%>$MysqlTool::font<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID} target=body>$server->{'server'}:$server->{'port'}</a></font></td>";
    print "<td align=right width=100% nowrap>$MysqlTool::font";

    my @server_options;

    if( $server->{'admin_mode'} ) {
        push(@server_options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.new_db._=1 target=body>Create Database</a>");
        push(@server_options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&edit_server_grant=1#EDITGRANT target=body>New User</a>");
        push(@server_options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.in_flush._=1 target=body>Execute \"Flush\" Statement</a>");
    }

    print join(' | ', @server_options);
    print "</td></tr></tr>";
    print "</table></td></tr></table>";
    
    if( $q->param('_.in_db._') ) {
        MysqlTool::Db->new($self)->display($server);
        return;
    }

    print "<table cellpadding=0 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::light_grey><td><table cellpadding=0 cellspacing=0 border=0 width=100%><tr>";
    print "<td><img src=$MysqlTool::image_dir/transparent.gif width=17 height=17 border=0></td>";
    print "<td><img src=$MysqlTool::image_dir/dirtree_elbow.gif border=0></td>";
    print "<td width=21><img src=$MysqlTool::image_dir/db.gif border=0 width=21 height=17></td>";
    print "<td>$MysqlTool::font<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.db_id._=$database->{ID}&_.in_db._=1 target=body>$database->{'db'}</a></font></td>";
    print "<td align=right width=100%>$MysqlTool::font";
    my @options;
    push(@options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.db_id._=$database->{ID}&new_table=1&_.in_db._=1 target=body>New Table</a>");
    push(@options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.db_id._=$database->{ID}&_.sql_frames._=1&_.table._=" . $q->param('_.table._') . " target=body>Execute SQL Statement</a>") unless $q->param('_.in_statement._');
    push(@options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.db_id._=$database->{ID}&_.generate_scripts._=1&_.table._=" . $q->param('_.table._') . " target=body>Generate \"Create Table\" Script</a>");
    print join(' | ', @options);
    print "</font></td>"; 
    print "</tr></table></td></tr>";
    print "</table>";

    
    if( $q->param('_.in_statement._') ) {
        $query_obj->display_statement_frame($database);
        return;
    } elsif( $q->param('_.generate_scripts._') ) {
        MysqlTool::Dump->new($self)->display_generate_scripts($server);
        return;
    }

    if( $q->param('_.in_table._') ) {
        MysqlTool::Table->new($self)->display($database);
        return;
    }
    
    print "<table cellpadding=0 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::light_grey><td><table cellpadding=0 cellspacing=0 border=0 width=100%><tr><td>";
    print "<table cellpadding=0 cellspacing=0 border=0>";
    print "<tr>";
    print "<td><img src=$MysqlTool::image_dir/transparent.gif border=0 width=17 height=17></td>";
    print "<td><img src=$MysqlTool::image_dir/transparent.gif border=0 width=17 height=17></td>";
    print "<td><img src=$MysqlTool::image_dir/dirtree_elbow.gif border=0></td>";
    print "<td width=19><img src=$MysqlTool::image_dir/table.gif border=0 width=19 height=17></td>";
    print "<td>$MysqlTool::font<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&_.in_table._=1&_.table._=" . $q->param('_.table._') . ">", $q->param('_.table._') . "</a></font></b></font></td>";
    print "</tr>";
    print "</table>";
    print "</td>";
    print "<td align=right>$MysqlTool::font";

    my @table_options;
    if( $self->compare_version($database->{'mysql_version'}, '3.23.0') ) {
        push(@table_options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&edit_table=1&_.table._=" . $q->param('_.table._') . "&_.db_id._=$database->{ID}&_.in_db._=1>Edit</a>");
        push(@table_options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&check=1&_.table._=" . $q->param('_.table._') . "&_.in_table._=1>Check</a>");
    }
    if( $self->compare_version($database->{'mysql_version'}, '3.22.7') ) {
        push(@table_options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&optimize=1&_.table._=" . $q->param('_.table._') . "&_.in_table._=1>Optimize</a>");
    }
    push(@table_options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=" . $q->param('_.server_id._') . "&_.db_id._=$database->{ID}&_.in_db._=1&drop_table=" . $q->param('_.table._') . " onClick=\"return confirm('Are you sure you want to drop table: " . $q->param('_.table._') . "?  This can\\'t be undone')\">Drop</a>");
    push(@table_options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.db_id._=$database->{ID}&_.sql_frames._=1&_.table._=" . $q->param('_.table._') . "&_.browse._=1 target=body>Browse Records</a>");
    push(@table_options, "<a href=$MysqlTool::start_page?_.in_main._=1&_.server_id._=$server->{ID}&_.db_id._=$database->{ID}&_.sql_frames._=1&_.table._=" . $q->param('_.table._') . "&_.browse._=1&_.new_record._=1 target=body>New Record</a>");
    print join(' | ', @table_options);

    print "</font></td></tr></table></td></tr>";
    print "</table>";
    
    if( $q->param('_.in_field._') ) {
        MysqlTool::Field->new($self)->display($database);
        return;
    }

    print $q->end_html;
}

sub display_edit_grant {
    my $self = shift;
    my $database = shift;

    my $dbh = $database->{'dbh'};
    $dbh->do("use mysql");

    my $q = $self->{'CGI'};

    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::dark_color>";
    print $q->startform( -action => $MysqlTool::start_page, -method => 'POST' );

    print $q->hidden( -name => '_.in_main._' );
    print $q->hidden( -name => '_.server_id._' );
    print $q->hidden( -name => '_.db_id._' );
    print $q->hidden( -name => 'user' );
    print $q->hidden( -name => 'host' );
    print $q->hidden( -name => '_.in_db._' );
    print $q->hidden( -name => 'edit_grant' );
    print $q->hidden( -name => '_.table._' );
    print $q->hidden( -name => '_.in_table._' );
    print $q->hidden( -name => '_.in_field._' );
    print $q->hidden( -name => 'field' );
    print $q->hidden( -name => 'table_sortby' );
    print $q->hidden( -name => 'index_sortby' );
    print $q->hidden( -name => 'db_priv_sortby' );

    print "<td>$MysqlTool::font<font color=white>", ( $q->param('user') ? 'Edit grant for user: <b>' . $q->param('user') . '@' . $q->param('host') . '</b>' : 'New grant' ), "</font></font></td>";
    print "</tr>";
    print "</table>";
    
    print "<script language='JavaScript'>\n";
    print "function check_all(form_elem, option) {\n";
    print "\tfor( i = 0; i < form_elem.length; i++ ) {\n";
    print "\t\tform_elem[i].checked = option;\n";
    print "\t}\n";
    print "\tif( document.forms[0].grant_option != null ) document.forms[0].grant_option.checked = option;\n";
    print "}\n";
    print "</script>\n";
    
    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
    
    my @columns = $q->param('field') ? qw(Select_priv Insert_priv Update_priv) : qw(Select_priv Insert_priv Update_priv Delete_priv Create_priv Drop_priv Index_priv Alter_priv);
    my %labels  = map { $_, (split(/_/, $_, 2))[0] } @columns;
    
    unless( $q->param('user') ) {
        
        $q->param('user_option', 'use_existing') unless $q->param('user_option');

        print "<tr bgcolor=$MysqlTool::dark_grey><td colspan=2>$MysqlTool::font", "User Options</font></td></tr>";
        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td nowrap>$MysqlTool::font<input type=radio name=user_option value='use_existing'" . ( ($q->param('user_option') eq 'use_existing') ? ' CHECKED' : '' ) . ">Select existing user</font></td>";
        print "<td width=100%>$MysqlTool::font", "<select name=existing_user onFocus='document.forms[0].user_option[0].checked = true;'><option value=''>- select -</option>";
        
        $q->param('existing_user', '') unless $q->param('existing_user');
        my $sth = $dbh->prepare("SELECT User, Host FROM user order by User, Host");
        $sth->execute;
        while( my $row = $sth->fetchrow_hashref ) {
            print "<option value='$row->{'User'}\@$row->{'Host'}'", ( $q->param('existing_user') eq "$row->{'User'}\@$row->{'Host'}" ? ' SELECTED' : '' ), ">$row->{'User'}\@$row->{'Host'}</option>"; 
        }
        print "</select></font></td>";
        print "</tr>";

        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td nowrap valign=top>$MysqlTool::font<input type=radio name=user_option value='new_user'" . ( $q->param('user_option') eq 'new_user' ? ' CHECKED' : '' ) . ">New User</font></td>";
        print "<td width=100%><table cellpadding=2 cellspacing=2 border=0 width=100%>";
        print "<tr>";
        print "<td align=right nowrap>$MysqlTool::font", "UserName:</font></td>";
        print "<td width=100%>$MysqlTool::font", $q->textfield( -name => 'username', -size => '16', -maxlength => 16, -onFocus => 'document.forms[0].user_option[1].checked = true;' ), "</font></td>";
        print "</tr>";
        print "<tr>";
        print "<td align=right nowrap>$MysqlTool::font", "Host:</font></td>";
        print "<td width=100%>$MysqlTool::font", $q->textfield( -name => 'newuser_host', -size => '40', -maxlength => 60, -onFocus => 'document.forms[0].user_option[1].checked = true;' ), "</font></td>";
        print "</tr>";
        print "<tr>";
        print "<td align=right nowrap>$MysqlTool::font", "Password:</font></td>";
        print "<td width=100%>$MysqlTool::font", $q->password_field( -name => 'password', -size => '16', -onFocus => 'document.forms[0].user_option[1].checked = true;' ), "</font></td>";
        print "</tr>";        
        print "<tr>";
        print "<td align=right nowrap>$MysqlTool::font", "Confirm Password:</font></td>";
        print "<td width=100%>$MysqlTool::font", $q->password_field( -name => 'password2', -size => '16', -onFocus => 'document.forms[0].user_option[1].checked = true;' ), "</font></td>";
        print "</tr></table></td>";
        print "</tr>";
    }
    
    my %data;
    
    if( $q->param('Save') ) {
        %data = map { $_, 'Y' } $q->param('grant_options');
    } else {
        if( $q->param('user') ) {
            my($table, @cond);
            if( $q->param('field') ) {
                $table = 'columns_priv';
                @cond = ('Db = ' . $dbh->quote($database->{db}), 'User = ' . $dbh->quote($q->param('user')), 'Host = ' . $dbh->quote($q->param('host')), 'Table_name = ' . $dbh->quote($q->param('_.table._')), 'Column_name = ' . $dbh->quote($q->param('field')));
            } elsif( $q->param('_.table._') ) {
                $table = 'tables_priv';
                @cond = ('Db = ' . $dbh->quote($database->{db}), 'User = ' . $dbh->quote($q->param('user')), 'Host = ' . $dbh->quote($q->param('host')), 'Table_name = ' . $dbh->quote($q->param('_.table._')));
            } else {
                $table = 'db';
                @cond = ('Db = ' . $dbh->quote($database->{db}), 'User = ' . $dbh->quote($q->param('user')), 'Host = ' . $dbh->quote($q->param('host')));
            }

            my $sth = $dbh->prepare("SELECT * FROM $table WHERE " . join(' AND ', @cond));
            $sth->execute;

            %data = %{ $sth->fetchrow_hashref };
            
            if( $q->param('field') ) {
                foreach( split(/,/, $data{'Column_priv'}) ) {
                    $data{$_ . "_priv"} = 'Y';
                }
            } elsif( $q->param('_.table._') ) {
                foreach( split(/,/, $data{'Table_priv'}) ) {
                    $data{$_ . "_priv"} = 'Y';
                }
            }
            
            $sth->finish;
        }
    }
    
    print "<tr bgcolor=$MysqlTool::dark_grey><td colspan=2>$MysqlTool::font", "Privileges</font></td></tr>" unless $q->param('user');

    print "<tr bgcolor=$MysqlTool::light_grey>";
    print "<td align=right valign=top nowrap>$MysqlTool::font", ( $q->param('_.table._') ? ( $q->param('field') ? "Column" : "Table" ) : "Database" ), " Scope Privileges<BR><BR>(<a href=\"javascript:void check_all(document.forms[0].grant_options, true);\">Check All</a>\n | <a href=\"javascript:void check_all(document.forms[0].grant_options, false);\">Un-check All</a>)</font></td>";
    print "<td width=100%>$MysqlTool::font";
    
    if( $q->param('field') ) {
        foreach( 0 .. 2 ) {
            my $val = $data{$columns[$_]} || '';
            print "<input type=checkbox name='grant_options' value=$columns[$_]" . ($val eq 'Y' ? ' CHECKED' : '') . ">$labels{$columns[$_]}<BR>";
        }
    } else {
        print "<table cellpadding=2 cellspacing=2 border=0>";
        print "<tr>";
        print "<td valign=top>$MysqlTool::font";
        foreach( 0 .. 3 ) {
            my $val = $data{$columns[$_]} || '';
            print "<input type=checkbox name='grant_options' value=$columns[$_]" . ($val eq 'Y' ? ' CHECKED' : '') . ">$labels{$columns[$_]}<BR>";
        }
        print "</td>";
        print "<td> &nbsp; </td>";
        print "<td valign=top>$MysqlTool::font";
        foreach( 4 .. 7 ) {
            my $val = $data{$columns[$_]} || '';
            print "<input type=checkbox name='grant_options' value=$columns[$_]" . ($val eq 'Y' ? ' CHECKED' : '') . ">$labels{$columns[$_]}<BR>";
        }
        print "</td>";
        print "</tr></table>";
    }
    
    print "</td></tr>";

    unless( $q->param('field') ) {
        $data{'Grant_priv'} ||= 'N';
        print "<tr bgcolor=$MysqlTool::light_grey>";
        print "<td align=right nowrap>$MysqlTool::font", "Grant Option:</font></td>";
        print "<td width=100%>$MysqlTool::font", $q->checkbox( -name => 'grant_option', -value => 1, -label => '', -checked => ( $data{'Grant_priv'} eq 'Y' ? 1 : 0 ) ), "</font></td>";
        print "</tr>";
    }

    print "</table>";

    print "<table cellpadding=2 cellspacing=2 border=0 width=100%>";
    print "<tr bgcolor=$MysqlTool::dark_grey><td align=center>$MysqlTool::font<font color=$MysqlTool::dark_color>", $q->submit('Save'), $q->submit('Cancel'), "</font></font></td></tr>";
    print "</table>";

    print $q->endform;
}

sub edit_grant {
    my $self = shift;
    my $database = shift;

    my $dbh = $database->{'dbh'};
    $dbh->do("use mysql");

    my $q = $self->{'CGI'}; 
    
    my @columns = $q->param('field') ? qw(Select_priv Insert_priv Update_priv) : qw(Select_priv Insert_priv Update_priv Delete_priv Create_priv Drop_priv Index_priv Alter_priv);
    my %priv = map { $_, 'Y' } $q->param('grant_options');

    my $table;
    if( $q->param('field') ) {
        $table = 'columns_priv';
    } elsif( $q->param('_.table._') ) {
        $table = 'tables_priv';
    } else {
        $table = 'db';
    }

    unless( $q->param('user') ) {
        
        my($user, $host);
        
        if( $q->param('user_option') eq 'use_existing' ) {
            return 'please create a new user' unless( $q->param('existing_user') );

            ($user, $host) = split(/\@/, $q->param('existing_user'));
            $user ||= '""';
            $host = '"%"' if( $host eq '%' );

        } else {
            return "passwords don't match" unless( $q->param('password') eq $q->param('password2') );
            
            #warn keys %priv;

            $user = $q->param('username') || '';
            $host = $q->param('newuser_host') || '%';

            #$host = '"%"' if( $host eq '%' );
        }

        my $sql = "GRANT " . ( %priv ? join( ( $q->param('field') ? " (" . $q->param('field') . ")" : '') . ",", map((split(/_/, $_, 2))[0], keys %priv)) : 'USAGE' ) . ( $q->param('field') ? " (" . $q->param('field') . ")" : '' ) . " ON $database->{db}." . ( $q->param('_.table._') ? $q->param('_.table._') : '*' ) . " TO '".$user."'\@'".$host."'";
        $sql .= " IDENTIFIED BY '" . $q->param('password') . "'" if $q->param('password');
        $sql .= " WITH GRANT OPTION" if $q->param('grant_option');
            
        #warn "$sql\n";

        $dbh->do($sql) or return $dbh->errstr;

    } else {
        my $sql = "UPDATE $table SET ";

        if( $q->param('field') ) {
            $sql .= "Column_priv = '" . join(",", map((split(/_/, $_, 2))[0], grep($priv{$_} eq 'Y', @columns))) . "'";
        } elsif( $q->param('_.table._') ) {
            $sql .= "Table_priv = '" . join(",", map((split(/_/, $_, 2))[0], grep($priv{$_} eq 'Y', @columns))) . ( $q->param('grant_option') ? ",Grant" : '' ) . "'";
        } else {
            $sql .= join(',', map "$_ = " . $dbh->quote( $priv{$_} eq 'Y' ? 'Y' : 'N' ), @columns ) . ", Grant_priv = " . $dbh->quote( $q->param('grant_option') ? 'Y' : 'N' );
        }
        
        $sql .= " WHERE Db = " . $dbh->quote($database->{db}) . " AND User = " . $dbh->quote($q->param('user')) . " AND Host = " . $dbh->quote($q->param('host'));
        $sql .= " AND Table_name = " . $dbh->quote($q->param('_.table._')) if $q->param('_.table._');
        $sql .= " AND Column_name = " . $dbh->quote($q->param('field')) if $q->param('field');

        #warn "$sql\n";

        $dbh->do($sql) or return $dbh->errstr;
        $dbh->do("FLUSH PRIVILEGES");
    }

    return 0;
}

sub column_definitions {
    my($self, $database, $table, $field) = @_;

    my $dbh = $database->{'dbh'};
    my $sth = $dbh->prepare("DESC $table");
    
    $sth->execute;
    my @data;

    while(my $data = $sth->fetchrow_hashref ) {
        push(@data, $data) 
    }
    $sth->finish;

    return \@data;
}

sub compare_version {
    my($self, $version, $compare) = @_;

    my($v_major, $v_minor, $v_rev, $c_major, $c_minor, $c_rev);

    $version =~ /^(\d+?)\.(\d+?)\.(\d+?)$/;
    $v_major = $1; $v_minor = $2; $v_rev = $3;

    $compare =~ /^(\d+?)\.(\d+?)\.(\d+?)$/;
    $c_major = $1; $c_minor = $2; $c_rev = $3;
    
    $self->pad($v_major, $v_minor, $v_rev, $c_major, $c_minor, $c_rev);
    
    $version = "$v_major$v_minor$v_rev";
    $compare = "$c_major$c_minor$c_rev";
    
    #warn "version: $version\n";
    #warn "compare: $compare\n";

    return $version >= $compare ? 1 : 0;
}

sub pad {
    foreach(0 .. $#_ ) {
        if( $_[$_] < 10 ) {
            $_[$_] = '0' . $_[$_];
        }
    }
}

sub manage_session {
    my $self = shift;

    my $q = $self->{'CGI'};
    
    if( $MysqlTool::mode eq 'SINGLE USER') {
        print $q->header(-type => 'text/html' . ( $MysqlTool::charset ? "; charset=$MysqlTool::charset" : '' ));
        return 1;
    }
    
    my $message;
    if( $q->param('_..connect.._') && !$q->cookie('mysqltool_cookie_test')) {
        $message = 'Please enable cookies. Multi-user MysqlTool uses cookies to store encrypted connection information.';
    } elsif( $q->param('_..connect.._') ) {
        my %conn;

        if( %MysqlTool::allowed_servers && !( $MysqlTool::allowed_servers{ $q->param('_..server.._') }) ) {
            $message = "Invalid server!";
        } else {
            $conn{user} = $q->param('_..db_user.._');
            $conn{pass} = $q->param('_..db_pass.._');

            if( %MysqlTool::allowed_servers ) {
                $conn{server} = $q->param('_..server.._');
                $conn{port} = $MysqlTool::allowed_servers{ $q->param('_..server.._') };
            } else {
                $conn{server} = $q->param('_..server.._');
                $conn{port} = $q->param('_..port.._') || 3306;
            }
            $conn{db} = $q->param('_..db.._') || 'mysql';
            $conn{is_admin} = $q->param('_..is_admin.._');

            my @conn = ("DBI:mysql:database=$conn{db};host=$conn{server};port=$conn{port}", $conn{user}, $conn{pass});

            my $dbh =  DBI->connect(@conn, { PrintError => 0 });

            unless( $dbh ) {
                $message = $DBI::errstr;
            } else {
                $self->{'conn_params'} = \%conn;
			    $self->send_session_cookie;
                $dbh->disconnect;
                return 1;
            }
        }
    } elsif( $q->param('_..logout.._') ) {
		# do nothing
	} elsif (($MysqlTool::mode eq 'MULTI USER') && (length($MysqlTool::private_key) < 8) ) {
		$message = 'MysqlTool::private_key is less than 56 bits (8 bytes). Please install a longer key in mysqltool.conf!';
    } elsif( $q->cookie('mysqltool') ) {    
        my $content = pack('H*', $q->cookie('mysqltool'));

        my $x = 0;
        my $decrypted = "";

		$self->{'cipher'} ||= Crypt::Blowfish->new(pack("H56", $MysqlTool::private_key));
        while( $x <= length($content) - 1 ) {
            my $data = substr($content, $x, 8);

            $decrypted .= $self->{'cipher'}->decrypt($data);
            $x += 8;
        }
        $decrypted =~ s/\s*$//;
        
        my @conn = split('-.-~~delimiter~~-.-', $decrypted);
        
        if( $#conn != 7 ) {
            $message = 'Unable to decrypt cookie contents.  Either the server key has changed or your cookie is invalid. Please log in again.';
		} elsif ($conn[7] lt time) {
			$message = 'Your connection has expired. Please log in again.';
		} elsif ($conn[6] ne $ENV{REMOTE_ADDR} ) {
			$message = 'IP address in cookie does not match yours ($ENV{REMOTE_ADDR}). Please log in again.';
        } else {
            $self->{'conn_params'} = { 'user' => $conn[0], 'pass' => $conn[1], 'server' => $conn[2], 'port' => $conn[3], 'db' => $conn[4], 'is_admin' => $conn[5] };
			$self->send_session_cookie;
            return 1;
        }
    } else {
        $message = "You aren't logged in or your session has expired.";
    }
    
    $self->{login_message} = $message;

    return 0;
}

sub send_session_cookie {
	my $self = shift;
	my $q = $self->{'CGI'};

    $self->{'cipher'} ||= Crypt::Blowfish->new(pack("H56", $MysqlTool::private_key));
	my %conn = %{ $self->{'conn_params'} };

	my $session_expiration = time + $MysqlTool::session_timeout_seconds;
	my $content = join('-.-~~delimiter~~-.-', ($conn{user},$conn{pass},$conn{server},$conn{port},$conn{db},$conn{is_admin},$ENV{REMOTE_ADDR},$session_expiration,));
    
	my $x = 0;
	my $encrypted = "";

	while( $x <= length($content) - 1 ) {
		my $data = substr($content, $x, 8);
        $data .= " " x (8 - length($data)) if( length($data) < 8 );

        $encrypted .= $self->{'cipher'}->encrypt($data);
        $x += 8;
	}

    $encrypted = join('',unpack 'H*',$encrypted);

    my $cookie = $q->cookie( -name      => 'mysqltool',
                             -value     => $encrypted,
                             -expires   => $MysqlTool::cookie_expires );

    print $q->header( -cookie => $cookie, -type => 'text/html' . ( $MysqlTool::charset ? "; charset=$MysqlTool::charset" : '' ) );
}

sub display_login {
    my $self = shift;
    my $message = $self->{login_message};

    my $q = $self->{'CGI'};
    my $r = $self->{'Apache'};
    my $tt = $self->{'TT'};

    my $cookie = $q->cookie( -name => 'mysqltool', -value => '', -expires => '-1d');
    my $cookie_test = $q->cookie( -name => 'mysqltool_cookie_test', -value=> '1', -expires => '+30d');
    
    my $javascript = "function is_top(w) { return (w.parent == w); }\nif (is_top(window.self) != true) { parent.location = \'$MysqlTool::start_page\'; }\n";

    print $q->header( -cookie => [$cookie, $cookie_test], -type => 'text/html' . ( $MysqlTool::charset ? "; charset=$MysqlTool::charset" : '' ) ),
          $q->start_html(-title => $MysqlTool::title, -bgcolor => 'white', 
                         -link => $MysqlTool::dark_color, -alink => $MysqlTool::dark_color, 
                         -vlink => $MysqlTool::dark_color,
                         -script => { -language=>'JAVASCRIPT', -code=>$javascript },
                         -style=> { src => 'bootstrap/css/bootstrap.css' }),
          $q->startform( -method => 'POST', -action => $MysqlTool::start_page, -target => '_top', -class => 'form-horizontal');

    my $stash = { 
      cgi => $q, 
      message => $message, 
      VERSION => $MysqlTool::VERSION,
      allowed_server_values =>  [ keys %MysqlTool::allowed_servers ],
      allowed_server_labels => { map { $_, "$_:$MysqlTool::allowed_servers{$_}" } keys %MysqlTool::allowed_servers }
    };

    $tt->process('login.tt', $stash) || return fail($r, $Apache2::Const::SERVER_ERROR, $tt->error());

    print $q->endform . $q->end_html;

    return 0;
}

sub generate_key {
    srand( time() ^ ($$ + ($$ << 15)) );

    my @chars = ( 'a' .. 'z', 'A' .. 'Z', 0 .. 9 ); 
    return join("", @chars[ map { rand @chars } ( 1 .. 56 ) ]);
}

sub set_defaults {
	my $self = shift;

    $MysqlTool::title ||= 'MysqlTool';
    $MysqlTool::font ||= '<font face=Helvetica size=-1>';
    $MysqlTool::dark_color ||= '#336699';
    $MysqlTool::dark_grey ||= '#CCCCCC';
    $MysqlTool::light_grey ||= '#EAEAEA';
    $MysqlTool::image_dir ||= 'images';
    $MysqlTool::start_page ||= 'index.cgi';
    $MysqlTool::query_frame_height ||= 300;
    $MysqlTool::row_header_frequency ||= 20;
    $MysqlTool::cookie_expires ||= '+20m';
    $MysqlTool::session_timeout_seconds ||= 1200;
    $MysqlTool::charset ||= '';

    $MysqlTool::mode ||= 'MULTI USER';

    if(!%MysqlTool::servers) {
        $MysqlTool::mode = 'MULTI USER';
    }

}

sub DESTROY {
    my $self = shift;
    
    if( defined($self->{'servers'}) ) {
        foreach( keys %{ $self->{'servers'} } ) {
            $self->{'servers'}->{$_}->{'dbh'}->disconnect if( defined($self->{'servers'}->{$_}->{'dbh'}) );
            delete( $self->{'servers'}->{'dbh'} );
        }
    }
}

1;

__END__

=head1 NAME

MysqlTool - Web-based administration tool for mysql

=head1 SYNOPSIS

use MysqlTool;

&MysqlTool::handler();

=head1 DESCRIPTION

MysqlTool provides a graphical alternative to the mysql command
line program and is I<very> useful for managing one or more mysql
server installations.

=head1 SETUP

As of version 0.90, explicit definition of $MysqlTool::servers is no
longer required. 

=head2 MysqlTool can be run in two different modes. 

=over 4

=item MysqlTool as a 'single user' application --

In 'single user' mode, connection information is preset
and stored in a configuration file. In single user mode, the 
webserver MysqlTool runs under is responsible for authentication,
which usually means access is restricted by means of an htaccess file.
Anyone who has access to this 'single user' MysqlTool installation has
access to all of the databases defined in the configuration file.
See L</SINGLE USER MODE> for details.

=item MysqlTool as a 'multi user' app (default) --

In this mode a user provides connection
information via a form interface when first connecting to MysqlTool.
This information is hopefully sent over an SSL-encrypted link. MysqlTool
will then use Crypt::Blowfish to encrypt this database connection 
information and store the crypted information in a cookie. In multi
user mode, many different users may be connected to the same 
instance of mysqltool using many different databases at the same time.
See L</MULTI USER MODE> for details.

=back

=head2 First step - install the modules

	gunzip MysqlTool-x.xx.tar.gz
	tar -xvf MysqlTool-x.xx.tar
	cd MysqlTool-x.xx
	perl Makefile.PL
	make 
	make test
	make install

(You will need to be root for the "make install",
and perl Makefile.PL will fail unless the modules
CGI, DBI, DBD::mysql and Crypt::Blowfish are installed.)


=head2 Step 2 - edit and install mysqltool.conf

(See L</MYSQTOOL.CONF> for details about the syntax
of F<mysqltool.conf>. For basic installations, you
shouldn't need to edit F<mysqltool.conf> at all.)

Move the included default configuration file 
F<htdocs/mysqltool.conf> to a safe directory that
B<is not under your webserver document root>.
We recommend putting mysqltool.conf in the same directory
as your web server configuration files. 

	mv htdocs/mysqltool.conf {apache_root}/conf/

Change the owner of F<mysqltool.conf> to the root if
running under mod_perl, or to the user the webserver runs
as if you're running MysqlTool as a standalone CGI.

	chown root.root {apache_root}/conf/mysqltool.conf

or, if your webserver runs as nobody

	chown nobody {apache_root}/conf/mysqltool.conf

Next, change the permissions so only the owner can read the file.

	chmod 600 {apache_root}/conf/mysqltool.conf

=head2 Step 3 - edit index.cgi & install htdocs/

Open F<htdocs/index.cgi> with your favorite editor and
make sure the line 

	require '{apache_root}/conf/mysqltool.conf';

points to where you put your F<mysqltool.conf> file.

Copy the entire htdocs directory (index.cgi & images/) to 
somewhere within your webserver's document root.

	cp -R htdocs {apache_document_root}/htdocs/mysqltool

You should now have a working installation of MysqlTool. Follow
the pointers in the L<SEE ALSO> if you have problems and need help.

=head1 SINGLE USER MODE

The variable %MysqlTool::servers in F<mysqltool.conf> must be defined and
$MysqlTool::mode must equal 'SINGLE USER' for single user mode to work.

$MysqlTool::mode = 'SINGLE USER';

=head2 $MysqlTool::servers Variable

MysqlTool makes the connection to mysql based on the properties
you specify in the $MysqlTool::servers variable.

If you specify an admin username and password MysqlTool will
be able to automatically find databases that the specified mysql server stores, 
and will display functions available to users with server scope privileges.

Example:

	$MysqlTool::servers{1}->{'server'} = 'localhost';
	$MysqlTool::servers{1}->{'port'} = 3306;
	$MysqlTool::servers{1}->{'admin_user'} = 'root';
	$MysqlTool::servers{1}->{'admin_password'} = '';

	$MysqlTool::servers{2}->{'server'} = 'example.com';
	$MysqlTool::servers{2}->{'port'} = 3306;
	$MysqlTool::servers{2}->{'admin_user'} = 'root';
	$MysqlTool::servers{2}->{'admin_password'} = 'password';

If you don't want to connect as a user with server scope privileges then 
you must define specific databases, database usernames and database passwords.

Example:
    
	$MysqlTool::servers{1}->{'server'} = 'localhost';
	$MysqlTool::servers{1}->{'port'}   = 3306;
    
	$MysqlTool::servers{1}->{'databases'}->{1}->{'db'} = 'Historical_League';
	$MysqlTool::servers{1}->{'databases'}->{1}->{'username'} = 'hist_league';
	$MysqlTool::servers{1}->{'databases'}->{1}->{'password'} = 'password';
    
	$MysqlTool::servers{1}->{'databases'}->{2}->{'db'} = 'Northwind';
	$MysqlTool::servers{1}->{'databases'}->{2}->{'username'} = 'northwind';
	$MysqlTool::servers{1}->{'databases'}->{2}->{'password'} = 'password';

=head2 Single User Mode Security Considerations

B<Unless the webserver is only accessable from behind a very secure 
firewall, you should setup an 'htaccess' file to limit access to your
private installation of MysqlTool>.

See L</NOTES> below for a sample .htaccess file.

=head1 MULTI USER MODE

(Note: MysqlTool's mutli-user mode is a work in progress. We would greatly
appreciate advice and feedback about this initial implementation.)

$MysqlTool::mode = 'MULTI USER';

Multi-user mode means that connection information is provided by the client 
with each request. The database connection information is passed in the 
clear for the initial connection (wich should be over an encrypted SSL channel).
MysqlTool then uses $MysqlTool::private_key to encode the database connection parameters,
the client's IP, and a timeout value. This 
ciphertext is then passed back to the client and stored as a cookie named mysqltool. 
A cookie with a past expiration or incorrect IP address embedded within is considered
invalid and ignored.

Here's an explanation from Eric Smith, an originator of the idea -- 

"The only way that a stolen cookie is useful is if the attacker also has
the secret key.  And an attacker with the secret key but without a valid
cookie can't do anything.  The attacker has to obtain both the cookie
and the secret key, thus must attack both the client and the server,
in order to compromise the system."

=head2 MysqlTool::private_key

When MysqlTool is installed (when you run perl Makefile.PL), a 448-bit
key for Crypt::Blowfish is automatically generated and stored in mysqltool.conf as $MysqlTool::private_key. 
You may modify this key at any time, although it must be at least
eight characters. When you modify the private_key, existing sessions become
invalidated and users must resupply their connection parameters.

=head2 Is storing a cookie on the client side secure .. ?

We think so, but we would sure love to have someone audit our 
Crypt::Blowfish usage. The big question is -- does it matter that a good
deal of the ciphertext is known plaintext? Or do issues with known
plaintext not matter because the key is so large? Is our key generation
code random enough? Should we be using a larger subset of characters
when generating keys?

=head2 How do I limit access to only certain mysql servers?

Un-comment and define %MysqlTool::allowed_servers in mysqltool.conf and
restart apache.  The login page will display a popup menu with the servers
you defined.  Attempts to login to other servers will fail.

Please see the multi-user mode code in F<MysqlTool.pm> (lines 800 to 830,
and 760 to 790) for more details.

=head1 MYSQTOOL.CONF

TODO - document the configurable variables.

=head1 NOTES

=head2 Running under mod_perl

We recommend running MysqlTool under mod_perl. To do so, add the following lines
to your mod_perl server configuration file and restart the web server. 

	PerlRequire {apache_root}/conf/mysqltool.conf
	<Directory {apache_document_root}/htdocs/mysqltool>
		Options ExecCGI
		<Files *.cgi>
			SetHandler perl-script
			PerlHandler MysqlTool
		</Files>
	</Directory>

Also note -- just like with any other mod_perl program, you will need to restart Apache every time 
you make a change to mysqltool.conf.

=head2 Sample .htaccess file

	AuthType Basic
	AuthName "authentication required"
	AuthUserFile {apache_root}/conf/mysqltool.htpasswd
	AuthGroupFile /dev/null
	require valid-user

To create the file {apache_root}/conf/mysqltool.htpasswd, use Apache's 'htpasswd' command:

	{apache_root}/bin/htpasswd -c {apache_root}/conf/mysqltool.htpasswd [username]

For more information about htaccess files, check out the article titled 
'Using .htaccess Files with Apache' at:

	http://apachetoday.com/news_story.php3?ltsn=2000-07-19-002-01-NW-LF-SW	

=head1 SEE ALSO

The MysqlTool project homepage: 

    https://github.com/jingerso/mysqltool

Mysql documentation:

	http://mysql.com/doc/

=head1 TODO

- importing and exporting data

- query builder

- some sort of contextual help system

- a (better?) multi-user system that saves connection parameters on the server end

- a better SQL statement parsing system

- document mysqltool.conf (configurable) variables

- and, as always, find more testers, err, users

=head1 AUTHROS / ACKNOWLEDGMENTS

MysqlTool was created by Joe Ingersoll <joe.ingersoll at gmail dot com>.

Tweaks, testing and documentation by Abe Ingersoll <abe at abe dot us>.

Thanks to:

	Eric Smith <eric at brouhaha dot com>, for multi-user idea.
	John Van Essen <vanes002 at umn dot edu>, for bug fixes.
	Mathieu Longtin <mathieu at activebuddy dot com>, for bug report & suggestions.
	Bill Gerrard <bill at daze dot net>, for suggestions & bug reports.
	Ray Zimmerman <rz10 at cornell dot edu>, for bug report.
	Andy Baio <andy at kickmedia dot com>, for the early critique.
	Joerg Ungethuem <joerg dot ungethuem at innominate dot com>, bugfix.

=head1 COPYRIGHT

Copyright 2012 Joseph Ingersoll

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

=cut
