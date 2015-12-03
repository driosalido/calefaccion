#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Request::Common;
use JSON qw(decode_json);

my $number = $ENV{SMS_1_NUMBER};
my $sms_text = $ENV{SMS_1_TEXT};

my $ua = LWP::UserAgent->new;
my $response = $ua->request(POST 'http://localhost:3000/sms', [Body => $sms_text]);
if ($response->is_success) {
	my $res = decode_json $response->decoded_content;
	if ($res->{response}) {
		#Tenemos respuesta y mandamos el SMS
		my $cmd = "/usr/bin/gammu-smsd-inject TEXT $number -text \"". $res->{response} . '"';
		print "Executing $cmd\n";
		system($cmd);
        }
}
else {
	print STDERR $response->status_line, "\n";
}
