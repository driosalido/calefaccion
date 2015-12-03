#!/usr/bin/env perl

use WebService::Belkin::WeMo::Discover;
use WebService::Belkin::WeMo::Device;
use Mojolicious::Lite;
use Mojo::JSON;
use Data::Dumper;
use Encode;
use strict;

helper reply => sub {
    my $self    = shift;
    my $message = shift;
    my $reply = { response => $message };
    return $self->render( json => $reply );
};

get '/' => sub {
    my $self = shift;
    $self->render( text => "Servidor de Control de Calefaccion" );
};

post '/sms' => sub {
    my $self = shift;

    my $data = {
        "uas"  => $self->req->headers->user_agent,
        "Body" => $self->param('Body'),
    };

    $self->app->log->info( Dumper($data) );

    $self->res->headers->header( 'Content-Type' => 'application/json' );

    my $belkindb     = "/etc/belkin.db";
    my $wemoDiscover = WebService::Belkin::WeMo::Discover->new();
    my $discovered   = $wemoDiscover->load($belkindb);

    my $command = $self->param('Body');

    $self->app->log->info("Got command - $command");

    my $valid_commands = {
        '1' => 'test',
        '2' => 'status',
        '3' => 'commands',
	'4' => '<device|all> <on|off>',
    };

    if ( lc($command) eq "test" ) {
        $self->reply("Works!");
    }
    elsif ( lc($command) eq "status" ) {

        my $devices;
        foreach my $ip ( keys %{$discovered} ) {
            my $wemo = WebService::Belkin::WeMo::Device->new(
                ip => $ip,
                db => $belkindb
            );
            $devices .= $wemo->getFriendlyName();
            $devices .= "[" . $wemo->getBinaryState() . "],";
        }
        chop $devices;

        $self->reply($devices);

    }
    elsif ( lc($command) eq "commands" ) {

        my $commands;
        foreach my $cmd ( values %{$valid_commands} ) {
            $commands .= "$cmd,";
        }
        chop $commands;

        $self->reply($commands);

    }
    elsif ( lc($command) =~ m/(\w+) (on|off)/g ) {

        my $target = $1;
        my $action = $2;
        $self->app->log->info("t = $target, o = $action");

        if ( $target eq "all" ) {

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
            $self->reply("OK");
        }
        else {
            my $wemo;
            eval {
                $wemo = WebService::Belkin::WeMo::Device->new(name => $target,db   => $belkindb);
                1;
            };
            if ($@){
                $self->reply("ERROR - Device unknown");
                $self->app->log->info("Error al invocar WEMO [$!]");
            } else {
                $self->app->log->info("$action for wemo $_");
                if ( $action eq "off" ) {
                    $wemo->off();
                }
                if ( $action eq "on" ) {
                    $wemo->on();
                }
                $self->reply("OK");
            }
        }
    } else {
        $self->reply("ERROR - Bad Command");
    }

};

app->config( hypnotoad => { 
	listen => ['http://*:9000'],
	pid_file => '/run/wemo-server.pid',
	workers => 1,
} );

app->log->path('/var/log/wemo-server.log');
app->log->level('info');
app->start;
