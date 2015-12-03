#!/usr/bin/env perl

use WebService::Belkin::WeMo::Discover;
use WebService::Belkin::WeMo::Device;
use Mojolicious::Lite;
use JSON;
use Data::Dumper;

my $belkindb = "/etc/belkin.db";
my $tempsfile = "/run/temps.json";

my @CMDS   = qw(test status commands on off);
my %ROUTES = (
    test     => 'test',
    status   => 'status',
    commands => 'list_commands',
    on       => 'turn_on',
    off      => 'turn_off',
);

get '/' => sub {
    my $self = shift;
    $self->render( text => "Servidor de Control de Calefaccion" );
};

post '/sms' => sub {
    my $self = shift;
    my $msg  = $self->param('Body');
    $self->reply("ERROR - Bad Command") unless $msg;
    $self->app->log->info("Got Message - $msg");
    $msg =~ m/^([^ ]*)/;
    my $command = lc($1);
    if ( grep $_ eq $command, @CMDS ) {
        $self->app->log->info("Got Command [$command]");
        my $helper = $ROUTES{$command};
        $self->$helper($msg);
    }
    else {
        $self->reply("ERROR - Bad Command");
    }
};

###COMMANDS

helper test => sub {
    my $self = shift;
    return $self->reply("I'm working!");
};

helper status => sub {
    my $self = shift;
    my $devices;
    my $discovered = $self->discover;
    if ($discovered) {
        foreach my $ip ( keys %{$discovered} ) {
            my $wemo = WebService::Belkin::WeMo::Device->new(
                ip => $ip,
                db => $belkindb
            );
            $devices .= $wemo->getFriendlyName();
            $devices .= "[" . $wemo->getBinaryState() . "],";
        }
	my $temps = $self->get_temps;
	foreach my $temp (keys %{$temps->{'temp-in'}}){
		$devices .= $temp;
		$devices .= "[" . $temps->{'temp-in'}{$temp} . "],";	
	}
	chop $devices;
        $self->reply($devices);
    }
    else {
        return $self->reply("Problem discovering WEMO Devices");
    }
};

helper list_commands => sub {
    my $self = shift;
    my $commands;
    foreach (@CMDS) {
        $commands .= "$_,";
    }
    chop $commands;
    $self->reply($commands);
};

helper turn_on => sub {
    my ( $self, $msg ) = @_;
    if ( $msg =~ m/^([^ ]*) *([^ ]*)/g ) {
        my $device = $2;
        $self->app->log->info("Got Device $device");
        $self->turn( $device, 'on' );
        $self->status;
    }
    else {
        $self->reply("Device Missing , use 'on device' or 'on all'");
    }
};

helper turn_off => sub {
    my ( $self, $msg ) = @_;
    if ( $msg =~ m/^([^ ]*) *([^ ]*)/g ) {
        my $device = $2;
        $self->app->log->info("Got Device [$device]");
        $self->turn( $device, 'off' );
        $self->status;
    }
    else {
        $self->reply("Device Missing , use 'off device' or 'off all'");
    }
};

###REAL HELPERS
helper discover => sub {
    my $self         = shift;
    my $wemoDiscover = WebService::Belkin::WeMo::Discover->new();
    my $wemo;
    eval { 
        $wemo = $wemoDiscover->load($belkindb); 
    };
    $self->app->log->error("Failed to discover WEMO Devices $@") if ($@);
    return $wemo;
};

helper turn => sub {
    my ( $self, $target, $action ) = @_;
    my $discovered = $self->discover;
    if ($discovered) {

        #Let's turn on|off all of them...
        if ( $target eq "all" ) {
            $self->app->log->info("Turning $action every WEMO Device");
            foreach my $ip ( keys %{$discovered} ) {
                if ( $discovered->{$ip}->{'type'} eq "switch" ) {
                    my $wemo = WebService::Belkin::WeMo::Device->new(
                        ip => $ip,
                        db => $belkindb
                    );
                    if ( $action eq "off" ) {
                        $self->app->log->info("Turning off wemo $target");
                        $wemo->off();
                    }
                    if ( $action eq "on" ) {
                        $self->app->log->info("Turning on wemo $target");
                        $wemo->on();
                    }
                }
            }
        }
        else {
            my $wemo;
            eval {
                $wemo = WebService::Belkin::WeMo::Device->new(
                    name => $target,
                    db   => $belkindb
                );
                1;
            };
            if ($@) {
                $self->reply("ERROR - Device unknown");
                $self->app->log->error("Error al invocar WEMO [$@]");
            }
            else {
                $self->app->log->info("Turning $action for wemo $target");
                if ( $action eq "off" ) {
                    $wemo->off();
                }
                if ( $action eq "on" ) {
                    $wemo->on();
                }
            }
        }
    }
    else {
        #Nothing discovered
        return $self->reply("Problem discovering WEMO Devices");
    }
};

helper reply => sub {
    my $self    = shift;
    my $message = shift;
    my $reply   = { response => $message };
    $self->res->headers->header( 'Content-Type' => 'application/json' );
    return $self->render( json => $reply );
};

helper change_status => sub {
    my $self   = shift;
    my $device = shift;
    my $status = shift;
};

helper get_temps => sub {
    my $self = shift;
    my $json = JSON->new;
    my $json_text = do {
        open(my $json_fh, "<" , $tempsfile)
            or do { 
                $self->app->log->error("Error reading temps file [$!]");
            } ;
        local $/;
        <$json_fh>
    };
    my $data = $json->decode($json_text);
    return $data;
};

###CONFIGS

app->config(
    hypnotoad => {
        listen => ['http://*:9000'],

        #	pid_file => '/run/wemo-server.pid',
        workers => 1,
    }
);

app->log->path('log/wemo-server.log');
app->log->level('info');
app->start;
