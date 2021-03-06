#!/usr/bin/env perl
#  Copyright (C) 2012 Stephane Varoqui @SkySQL AB Co.,Ltd.
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#  Foundation, Inc.,
#  51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

package Scramble::ClusterConfig;
use Scramble::ClusterLog; 
use strict;
use warnings FATAL => 'all';
use English qw( -no_match_vars );
use Log::Log4perl qw(:easy);
use List::Util qw(first);
use File::stat qw();


our $VERSION = '0.01';

our $RULESET = {
	'this'                  => { 'required' => ['AGENT', 'TOOLS'], 'refvalues' => 'db' },
        'scramble'              => { 'multiple' => 0, 'template' => 'default', 'section' => {
                'log_level_node'                => { 'default' => 0 ,'values' => [0,1,2]},
                'log_level_transport'           => { 'default' => 0 ,'values' => [0,1,2]},
                'log_level_cluster'             => { 'default' => 0 ,'values' => [0,1,2]},
                'log_level_write_config'        => { 'default' => 0 ,'values' => [0,1,2]},
                'log_level_cluster_doctor'      => { 'default' => 0 ,'values' => [0,1,2]},
                'log_level_cloud_doctor'        => { 'default' => 0 ,'values' => [0,1,2]},
                'log_level_heartbeat'           => { 'default' => 0 ,'values' => [0,1,2]},
                'log_level_cloud_api'           => { 'default' => 0 ,'values' => [0,1]},
                'cluster_heartbeat_time'        => { 'default' => 10 },
                'cluster_monitor_interval'   => { 'default' => 30 },
                'cloud_heartbeat_time'          => { 'default' => 20 }
             }   
        },
        
        'copy_method'		=> { 
                'required' => ['TOOLS'], 'multiple' => 1, 'template' => 'default', 'section' => {
                    'backup_command'		=> { 'required' => 1 },
                    'restore_command'		=> { 'required' => 1 },
                    'incremental_command'       => { 'deprequired' => { 'incremental' => 1 } },
                    'incremental'		=> { 'default' => 0, 'boolean' => 1 },
                    'single_run'		=> { 'default' => 0, 'boolean' => 1 },
                    'true_copy'			=> { 'default' => 0, 'boolean' => 1 },
		}
	},
	'db' => { 'required' => 1, 'multiple' => 1, 'template' => 'default', 'section' => {
		'ip'				=> { 'required' => ['AGENT', 'MONITOR', 'TOOLS','SANDBOX'] },
		'cloud'                         => { 'refvalues' => 'cloud'  },
                'mode'				=> { 'required' => ['AGENT', 'MONITOR','SANDBOX'], 'values' => ['mysql', 'mariadb','proxy','spider','spidermonitor','ndbd','galera','tokudb', 'infinidb' ,'percona','ndbd-manager'] },
                'status'                        => { 'required' => ['AGENT', 'MONITOR','SANDBOX'], 'values' => ['master', 'slave','standalone', 'discard'] },
                'peer'				=> { 'deprequired' => { 'state' => 'master' }, 'refvalues' => 'db' , 'multiple' => 1 },
		'cluster_interface'		=> { 'required' => ['AGENT'] },
		'mysql_cnf'			=> { 'default' => 'etc/my.cnf' },
		'mysql_port'			=> { 'default' => 3306 },
		'mysql_server_id'		=> { 'default' => 1 },
                'mem_pct'                       => { 'default' => 25 },
                'io_pct'                        => { 'default' => 25 },
                'mysql_cnf'			=> { 'default' => '/etc/my.cnf' },
		'mysql_version'			=> { 'default' => 'mariadb-5.2.4' },
		'mysql_user'			=> { 'default' => 'skysql' },
		'mysql_password'		=> { 'default' => 'skyvodka' },
		'replication_user'		=> { 'required' => ['AGENT', 'TOOLS'] },
		'replication_password'          => { 'required' => ['AGENT', 'TOOLS'] },
                'cluster'                       => { 'refvalues' => 'cluster'  },
                'handlersocket_port'            => { 'default' => 2000 },
                'handlersocket_port_wr'         => { 'default' => 2001 },
                'handlersocket_address'         => { 'default' => '127.0.0.1' }
		}
	},
        
	'check'	=> { 'create_if_empty' => ['MONITOR'], 'multiple' => 1, 'template' => 'default', 'values' => ['ping', 'mysql', 'rep_backlog', 'rep_threads'], 'section' => {
		'check_period'			=> { 'default' => 5 },
		'trap_period'			=> { 'default' => 10 },
		'timeout'			=> { 'default' => 2 },
		'restart_after'			=> { 'default' => 10000 },
		'max_backlog'			=> { 'default' => 60 }		
		}
	},
        'agent' => { 'required' => 1, 'multiple' => 1, 'template' => 'default', 'section' => {
		'ip'				=> { 'required' => ['AGENT', 'MONITOR', 'TOOLS','SANDBOX'] },
		'cloud'                         => { 'refvalues' => 'cloud'  },
                'mode'				=> { 'required' => ['AGENT', 'MONITOR','SANDBOX'], 'values' => ['ndbd-manager'] },
                'peer'				=> { 'deprequired' => { 'mode' => 'ndbd' }, 'refvalues' => 'db' , 'multiple' => 1 },
                'cluster'                      => { 'refvalues' => 'cluster'  },
            }
	},	 


        'nosql' => { 'required' => 1, 'multiple' => 1, 'template' => 'default', 'section' => {
              	 'cloud'                        => { 'refvalues' => 'cloud'  },
                 'ip'                           => { 'required' => ['AGENT', 'MONITOR', 'TOOLS','SANDBOX'] },		           
		 'mode'				=> { 'required' => ['AGENT', 'MONITOR','SANDBOX'], 'values' => ['memcache', 'tarantool','mongodb','cassandra','hbase',"leveldb"] },
                 'status'                       => { 'required' => ['AGENT', 'MONITOR','SANDBOX'], 'values' => ['master', 'slave','standalone', 'discard'] },
                 'mem'				=> { 'required' => ['AGENT', 'MONITOR','SANDBOX'], 'default' => 16  },
                 'port'                         => { 'default' => 11211 },
                 'secondary_port'               => { 'default' => 33014 }, 
                 'admin_port'                   => { 'default' => 33015 }, 
                 'rows_per_wal'                 => { 'default' => 50000 },
                 'cluster'                      => { 'refvalues' => 'cluster'  },
	}}
        ,
        'cloud'	=> { 'required' => 1, 'multiple' => 1, 'template' => 'default', 'section' => {

                'user'                          => { 'required' => ['AGENT', 'MONITOR', 'TOOLS','SANDBOX'] },		           
		'password'                      => { 'required' => ['AGENT', 'MONITOR', 'TOOLS','SANDBOX'] },		           
                'host'                          => { 'required' => ['AGENT', 'MONITOR', 'TOOLS','SANDBOX'] },		           
		'version'                       => { 'required' => ['AGENT', 'MONITOR', 'TOOLS','SANDBOX'] },		           
		'template'                      => { 'required' => ['AGENT', 'MONITOR', 'TOOLS','SANDBOX'] },  
                'driver'                        => { 'required' => ['AGENT', 'MONITOR','SANDBOX'], 'values' => ['LOCAL','RACKSPACE', 'SLICEHOST','EC2','VCLOUD','BRIGHTBOX', 'CLOUDSIGMA', 'DREAMHOST',
                                'ECP','ELASTICHOST','GOGRID', 'IBM_SBC','LINODE','OPENNEBULA','SOFTLAYER' , 'VOXEL', 'VPSNET'] },
                'key'                           => { 'required' => ['AGENT', 'MONITOR', 'TOOLS','SANDBOX'] },
                'ex_vdc'                        => { 'default' => 'na' },
                'instance_type'                 => {'required' => ['AGENT', 'MONITOR','SANDBOX'], 'values' => ['t1.micro', 'c1.xlarge','m1.small','na'] },
		'security_groups'               => { 'default' => 'na'},
                'zone'                          => { 'default' => 'us-east-1b'},
                'region'                        => { 'default' => 'us-east-1'},
                'vpc'                           => { 'default' => 'na'},
                'subnet'                        => { 'default' => 'na'},
                'status'                        => { 'required' => ['AGENT', 'MONITOR','SANDBOX'], 'values' => ['master', 'slave'] },
                'public_key'                    => { 'default' => 'na'},
                'elastic_ip'                    => { 'default' => 'na'},
                'elastic_ip_id'                 => { 'default' => 'na'},
                'interface_vip_id'              => { 'default' => 'na'}
		 
	}},
        'cluster'	=> { 'required' => 1, 'multiple' => 1, 'template' => 'default', 'section' => {
                'label'        => { 'default' => ''},
                'vip'          => { 'default' => ''}
        }},
        'proxy'	=> { 'required' => 1, 'multiple' => 1, 'template' => 'default', 'section' => {
         	 'cloud'                        => { 'refvalues' => 'cloud'  },
                 'cluster'                      => { 'refvalues' => 'cluster'  },
                 'ip'                           => { 'required' => ['AGENT', 'MONITOR', 'TOOLS','SANDBOX'] },		           
		 'mode'                         => { 'required' => ['AGENT', 'MONITOR','SANDBOX'], 'values' => ['mysql-proxy', 'skygate'] },
                 'hosts'                        => { 'refvalues' => 'db', 'multiple' => 1 },       
                 'mysql_user'			=> { 'default' => 'skysql' },
		 'mysql_password'		=> { 'default' => 'skyvodka' },
                 'port'                         => { 'default' => 3306 },
                 'admin_user'			=> { 'default' => 'skysql' },
		 'admin_password'		=> { 'default' => 'skyvodka' },
                 'max_open_files'               => { 'default' => 4096 },
                 'proxy_fix_bug_25371'          => { 'default' => 1 },
                 'log_level'                    => { 'default' => 'debug' ,'values' => [ 'error','warning','info','message','debug']},
                 'event_threads'                => { 'default' => 1 }, 
                 'proxy_connect_timeout'        => { 'default' => 10 }, 
                 'proxy_read_timeout'           => { 'default' => 28800 }, 
                 'proxy_write_timeout'          => { 'default' => 28800 }, 
                 'proxy_pool_no_change_user'    => { 'default' => 1 },
                 'proxy_skip_profiling'         => { 'default' => 1 }, 
                 'lua_debug'			=> { 'default' => 1 , 'boolean' => 1 },
                 'script'                       => {'default' => 'scramble.lua' , 'required' => ['AGENT', 'MONITOR','SANDBOX'], 'values' => ['spider.template', 'scramble.template']   }
      
	}},
         'lb'	=> { 'required' => 1, 'multiple' => 1, 'template' => 'default', 'section' => {
                 'cloud'                        => { 'refvalues' => 'cloud'  },
                 'cluster'                      => { 'refvalues' => 'cluster'  },
                 'ip'                           => { 'required' => ['AGENT', 'MONITOR', 'TOOLS','SANDBOX'] },	
                 'vip'                          => { 'required' => ['AGENT', 'MONITOR', 'TOOLS','SANDBOX'] },		           
		 'mode'                         => { 'required' => ['AGENT', 'MONITOR','SANDBOX'], 'values' => ['keepalived', 'peacemaker','haproxy'] },
        	 'peer'                         => { 'deprequired' => { 'mode' => ['keepalived', 'peacemaker','haproxy']}, 'refvalues' => 'lb'  },
                 'mysql_user'			=> { 'default' => 'skysql' },
		 'mysql_password'               => { 'default' => 'skyvodka' },
                 'port'                         => { 'default' => 3306 },
                 'balance'                      => { 'default' => 'none', 'values' => ['none', 'DR','NAT'] },
                 'status'                       => { 'required' => ['AGENT', 'MONITOR','SANDBOX'], 'values' => ['master', 'slave'] },
                 'device'                       => { 'default' => 'eth0' }

	}}
        ,
         'bench'	=> { 'required' => 1, 'multiple' => 1, 'template' => 'default', 'section' => {
                'ip'                            => { 'required' => ['AGENT', 'MONITOR', 'TOOLS','SANDBOX'] },
                'mode'                          => { 'required' => ['AGENT', 'MONITOR','SANDBOX'], 'values' => ['dbt3', 'dbt2','sysbench','mysqlslap'] },
        	'cloud'                         => { 'refvalues' => 'cloud'  },
                'cluster'                       => { 'refvalues' => 'cluster'  },
                'warehouse'                     => { 'default' => '10' },
                'duration'			=> { 'default' => '100' },
                'concurrency'			=> { 'default' => '10' }
                
		
	}} ,
         'monitor'	=> { 'required' => 1, 'multiple' => 1, 'template' => 'default', 'section' => {
                'mode'                         => { 'required' => ['AGENT', 'MONITOR','SANDBOX'], 'values' => ['mycheckpoint', 'cacti','mulin', "monyog"] },
        	'smtp_from'		       => { 'default' => '' },
                'smtp_to'		       => { 'default' => '' },
                'smtp_host'                    => { 'default' => '' },
                'ip'                           => { 'required' => ['AGENT', 'MONITOR', 'TOOLS','SANDBOX'] },	
                'port'                         => { 'default' => 8080  },
        	'cloud'                        => { 'refvalues' => 'cloud'  },
                'cluster'                      => { 'refvalues' => 'cluster'  },
                'purge_days'                         => { 'default' => 1 }
		
	}},
        'http'  	=> { 'required' => 1, 'multiple' => 1, 'template' => 'default', 'section' => {
                'mode'                        => { 'required' => ['AGENT', 'MONITOR','SANDBOX'], 'values' => ['apache', 'nginx',] },
                'ip'                          => { 'required' => ['AGENT', 'MONITOR', 'TOOLS','SANDBOX'] },	
                'port'                        => { 'default' => 80  },
        	'cloud'                       => { 'refvalues' => 'cloud'  },
                'user'                        => { 'refvalues' => 'skysql'  },
                'password'                    => { 'refvalues' => 'skyvodka'  },
                'cluster'                     => { 'refvalues' => 'cluster'  },
    		'status'                      => { 'required' => ['AGENT', 'MONITOR','SANDBOX'], 'values' => ['standalone'] }
               
	}}
        
};


#-------------------------------------------------------------------------------
sub new($) {
	my $self = shift;

	return bless { }, $self; 
}

#-------------------------------------------------------------------------------
sub read($$) {
	my $self = shift;
	my $file = shift;
	my $fullname = $self->_get_filename($file);
	LOGDIE "Could not find a readable config file" unless $fullname;
	DEBUG "Loading configuration from $fullname";

	my $st = File::stat::stat($fullname);
	LOGDIE sprintf("Configuration file %s is world writable!", $fullname) if ($st->mode & 0002);

	my $fd;
	open($fd, "<$fullname") || LOGDIE "Can't read config file '$fullname'";
	my $ret = $self->parse($RULESET, $fullname, $fd);
	close($fd);
	return $ret;
}

sub write_json($$$) {
    my $self = shift;
    my $file = shift;
    my $json_text = shift;
#    open($fd, ">$file");
        
	 
}


#-------------------------------------------------------------------------------
sub parse(\%\%$*); # needed because parse is a recursive function
sub parse(\%\%$*) {
	my $config	= shift;
	my $ruleset = shift;
	my $file	= shift;	# name of file
	my $fd		= shift;
	my $line;
	
	while ($line = <$fd>) {
		chomp($line);

		# comments and empty lines handling
		next if ($line =~ /^\s*#/ || $line =~ /^\s*$/);

		# end tag
		return if ($line =~ /^\s*<\/\s*(\w+)\s*>\s*$/);

		if ($line =~ /^\s*include\s+(\S+)\s*$/) {
			my $include_file = $1;
			$config->read($include_file);
			next;
		}

		# start tag - unique section
		if ($line =~/^\s*<\s*(\w+)\s*>\s*$/) {
			my $type = $1;
			if (!defined($ruleset->{$type}) || !defined($ruleset->{$type}->{section})) {
				LOGDIE "Invalid section $type in '$file' on line $INPUT_LINE_NUMBER!";
			}
			if ($ruleset->{$type}->{multiple}) {
				LOGDIE "No section name specified for named section $type in '$file' on line $INPUT_LINE_NUMBER!";
			}
			$config->{$type} = {} unless $config->{$type};
			parse(%{$config->{$type}}, %{$ruleset->{$type}->{section}}, $file, $fd);
			next;
		}
		# empty tag - unique section
		if ($line =~/^\s*<\s*(\w+)\s*\/>\s*$/) {
			my $type = $1;
			if (!defined($ruleset->{$type}) || !defined($ruleset->{$type}->{section})) {
				LOGDIE "Invalid section $type in '$file' on line $INPUT_LINE_NUMBER!";
			}
			if ($ruleset->{$type}->{multiple}) {
				LOGDIE "No section name specified for named section $type in '$file' on line $INPUT_LINE_NUMBER!";
			}
			$config->{$type} = {}			unless $config->{$type};
			next;
		}
		# start tag - named section
		if ($line =~/^\s*<\s*(\w+)\s+([\w\-_]+)\s*>\s*$/) {
			my $type = $1;
			my $name = $2;
			if (!defined($ruleset->{$type}) || !defined($ruleset->{$type}->{section})) {
				LOGDIE "Invalid section $type in '$file' on line $INPUT_LINE_NUMBER!";
			}
			if (!$ruleset->{$type}->{multiple}) {
				LOGDIE "Section name specified for unique section $type in '$file' on line $INPUT_LINE_NUMBER!";
			}
			$config->{$type} = {}			unless $config->{$type};
			$config->{$type}->{$name} = {}	unless $config->{$type}->{$name};
			parse(%{$config->{$type}->{$name}}, %{$ruleset->{$type}->{section}}, $file, $fd);
			next;
		}

		# empty tag - named section
		if ($line =~/^\s*<\s*(\w+)\s+([\w\-_]+)\s*\/>\s*$/) {
			my $type = $1;
			my $name = $2;
			if (!defined($ruleset->{$type}) || !defined($ruleset->{$type}->{section})) {
				LOGDIE "Invalid section $type in '$file' on line $INPUT_LINE_NUMBER!";
			}
			if (!$ruleset->{$type}->{multiple}) {
				LOGDIE "Section name specified for unique section $type in '$file' on line $INPUT_LINE_NUMBER!";
			}
			$config->{$type} = {}			unless $config->{$type};
			$config->{$type}->{$name} = {}	unless $config->{$type}->{$name};
			next;
		}
		
		if ($line =~/^\s*(\S+)\s+(.*)$/) {
			my $var = $1;
			my $val = $2;
			LOGDIE "Unknown variable $var in '$file' on line $INPUT_LINE_NUMBER!" unless defined($ruleset->{$var});
			LOGDIE "'$var' should be a section instead of a variable in '$file' on line $INPUT_LINE_NUMBER!" if defined($ruleset->{$var}->{section});
			$val =~ s/\s+$//;
			@{$config->{$var}} = split(/\s*,\s*/, $val) if ($ruleset->{$var}->{multiple});
			$config->{$var} = $val unless ($ruleset->{$var}->{multiple});
			if ($ruleset->{$var}->{boolean}) {
				$ruleset->{$var}->{values} = [0, 1];
				if ($config->{$var} =~ /^(false|off|no|0)$/i) {
					$config->{$var} = 0;
				}
				elsif ($config->{$var} =~ /^(true|on|yes|1)$/i) {
					$config->{$var} = 1;
				}
			}
			next;
		}

		LOGDIE "Invalid config line in file '$file' on line $INPUT_LINE_NUMBER!";
	}
}

sub TO_JSON { return { %{ shift() } }; }
#-------------------------------------------------------------------------------

sub _get_filename($$) {
	my $self = shift;
	my $file = shift;
        return $file;
	$file .= '.conf' unless ($file =~ /\.cnf$/);
	my @paths = qw(/etc ./);

	my $fullname;
	foreach my $path (@paths) {
		if (-r "$path/$file") {
			$fullname = "$path/$file";
			last;
		}
	}
	FATAL "No readable config file $file in ", join(', ', @paths) unless $fullname;
	return $fullname;
}


sub get_ruleset($){
	my $self = shift;
        return $RULESET;
}


sub check($$) {
	my $self = shift;
	my $program = shift;
	$self->_check_ruleset('', $program, $RULESET, $self);
}

sub _check_ruleset(\%$$\%\%) {
	my $self	= shift;
	my $posstr	= shift;
	my $program	= shift;
	my $ruleset	= shift;
	my $config	= shift;

	foreach my $varname (keys(%{$ruleset})) {
		$self->_check_rule($posstr . $varname, $program, $ruleset, $config, $varname);
	}
}

#-------------------------------------------------------------------------------
sub _check_rule(\%$$\%\%$) {
	my $self	= shift;
	my $posstr	= shift;
	my $program	= shift;
	my $ruleset	= shift;
	my $config	= shift;
	my $varname	= shift;

	my $cur_rule = \%{$ruleset->{$varname}};

	# set default value if not defined
	if (!defined($config->{$varname}) && defined($cur_rule->{default})) {
		DEBUG "Undefined value for '$posstr', using default value '$cur_rule->{default}'";
		$config->{$varname} = $cur_rule->{default};
	}

	# check required
	if (defined($cur_rule->{required}) && defined($cur_rule->{deprequired})) {
		LOGDIE "Default value specified for required config entry '$posstr'" if defined($cur_rule->{default});
		LOGDIE "Invalid ruleset '$posstr' - deprequired should be a hash" if (ref($cur_rule->{deprequired}) ne "HASH");
		$cur_rule->{required} = _eval_program_condition($program, $cur_rule->{required}) if (ref($cur_rule->{required}) eq "ARRAY");
		my ($var, $val) = %{ $cur_rule->{deprequired} };
		# TODO WARN if field $var has a default value - this may not be evaluated yet.
		if (!defined($config->{$varname}) && $cur_rule->{required} == 1 && defined($config->{$var}) && $config->{$var} eq $val) {
			# TODO better error message for missing sections
			FATAL "Config entry '$posstr' is required because of '$var $val', but missing";
		}
	}
	elsif (defined($cur_rule->{required})) {
		$cur_rule->{required} = _eval_program_condition($program, $cur_rule->{required}) if (ref($cur_rule->{required}) eq "ARRAY");
		if (!defined($config->{$varname}) && $cur_rule->{required} == 1) {
			# TODO better error message for sections
			LOGDIE "Required config entry '$posstr' is missing";
			return;
		}
	}
	elsif (defined($cur_rule->{deprequired})) {
		LOGDIE "Invalid ruleset '$posstr' - deprequired should be a hash" if (ref($cur_rule->{deprequired}) ne "HASH");
		my ($var, $val) = %{ $cur_rule->{deprequired} };
		# TODO WARN if field $var has a default value - this may not be evaluated yet.
		if (!defined($config->{$varname}) && defined($config->{$var}) && $config->{$var} eq $val) {
			# TODO better error message for missing sections
			LOGDIE "Config entry '$posstr' is required because of '$var $val', but missing";
			return;
		}
	}

	return if (!defined($config->{$varname}) && !$cur_rule->{multiple});

	# handle sections
	if (defined($cur_rule->{section})) {

		# unique secions
		unless ($cur_rule->{multiple}) {
			# check variables of unique sections
			$self->_check_ruleset($posstr . '->', $program, $cur_rule->{section}, $config->{$varname});
			return;
		}

		# named sections ...

		# check if section name is one of the allowed
		if (defined($cur_rule->{values})) {
			my @allowed = @{$cur_rule->{values}};
			push @allowed, $cur_rule->{template} if defined($cur_rule->{template});
			foreach my $key (keys %{ $config->{$varname} }) {
				unless (defined(first { $_ eq $key; } @allowed)) {
					LOGDIE "Invalid $posstr '$key' in configuration allowed values are: '", join("', '", @allowed), "'"
				}
			}
		}

		# handle "create if empty"
		if (defined($cur_rule->{create_if_empty})) {
			$cur_rule->{create_if_empty} = _eval_program_condition($program, $cur_rule->{create_if_empty}) if (ref($cur_rule->{create_if_empty}) eq "ARRAY");
			if ($cur_rule->{create_if_empty} == 1) {
				$config->{$varname} = {} unless defined($config->{$varname});
				foreach my $value (@{$cur_rule->{values}}) {
					next if (defined($config->{$varname}->{$value}));
					$config->{$varname}->{$value} = {};
				}
			}
		}

		# handle section template
		if (defined($cur_rule->{template}) && defined($config->{$varname}->{ $cur_rule->{template} })) {
			my $template = $config->{$varname}->{ $cur_rule->{template} };	
			delete($config->{$varname}->{ $cur_rule->{template} });
			foreach my $var ( keys( %{ $template } ) ) {
				foreach my $key ( keys( %{ $config->{$varname} } ) ) {
					if (!defined($config->{$varname}->{$key}->{$var})) {
						$config->{$varname}->{$key}->{$var} = $template->{$var};
					}
				}
			}
		}

		# check variables of each named section
		foreach my $key ( keys( %{ $config->{$varname} } ) ) {
			$self->_check_ruleset($posstr . '->' . $key . '->', $program, $cur_rule->{section}, $config->{$varname}->{$key});
		}
		return;
	}

	# skip if undefined
	return if (!defined($config->{$varname}));
	
	# check if variable has one of the allowed values
	if (defined($cur_rule->{values}) || defined($cur_rule->{refvalues})) {
		my @allowed;
		if (defined($cur_rule->{values})) {
			@allowed = @{$cur_rule->{values}};
		}
		elsif (defined($cur_rule->{refvalues})) {
			if (defined($ruleset->{ $cur_rule->{refvalues} })) {
				# reference to section on current level
				my $reftype = ref($config->{ $cur_rule->{refvalues} });
				if ($reftype eq 'HASH') {
					@allowed = keys( %{ $config->{ $cur_rule->{refvalues} } } );
					# remove template section from list of valid values
					if (defined($ruleset->{ $cur_rule->{refvalues} }->{template})) {
						@allowed = grep { $_ ne $ruleset->{ $cur_rule->{refvalues} }->{template}} @allowed;
					}
				}
				elsif ($reftype eq 'ARRAY') {
					@allowed = @{ $config->{ $cur_rule->{refvalues} } };
				}
				else {
					return unless (ref($config->{ $cur_rule->{refvalues} }) eq "HASH");
#					LOGDIE "Could not find any $cur_rule->{refvalues}-sections";
				}
			}
			elsif (defined($RULESET->{ $cur_rule->{refvalues} })) {
				# reference to section on top level
				my $reftype = ref($self->{ $cur_rule->{refvalues} });
				if ($reftype eq 'HASH') {
					@allowed = keys( %{ $self->{ $cur_rule->{refvalues} } } );
					# remove template section from list of valid values
					if (defined($RULESET->{ $cur_rule->{refvalues} }->{template})) {
						@allowed = grep { $_ ne $RULESET->{ $cur_rule->{refvalues} }->{template}} @allowed;
					}
				}
				elsif ($reftype eq 'ARRAY') {
					@allowed = @{ $self->{ $cur_rule->{refvalues} } };
				}
				else {
					return unless (ref($self->{ $cur_rule->{refvalues} }) eq "HASH");
#					LOGDIE "Could not find any $cur_rule->{refvalues}-sections" unless (ref($self->{ $cur_rule->{refvalues} }) eq "HASH");
				}
			}
			else {
				LOGDIE "Invalid reference to non-section '$cur_rule->{refvalues}' for '$posstr'";
				return;
			}
		}
		if ($cur_rule->{multiple}) {
			for my $val ( @{ $config->{$varname} } ) {
				unless (defined(first { $_ eq $val; } @allowed)) {
					LOGDIE "Config entry '$posstr' has invalid value '$val' allowed values are: '", join("', '", @allowed), "'";
					return;
				}
			}
			return;
		}
		unless (defined(first { $_ eq $config->{$varname}; } @allowed)) {
			LOGDIE "Config entry '$posstr' has invalid value '$config->{$varname}' allowed values are: '", join("', '", @allowed), "'";
			return;
		}
	}
}

#-------------------------------------------------------------------------------
sub _eval_program_condition($$) {
	my $program = shift;
	my $value = shift;
	
	return 1 unless ($program);
	return 1 if (first { $_ eq $program; } @{ $value });
	return -1;
}

1;

