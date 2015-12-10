#!/usr/bin/env perl

use strict;
use warnings;
use v5.10.1;
use Test::More;
use Test::Exception;
use Test::LWP::UserAgent;
use HTTP::Response;

my $pkg;
BEGIN {
    $pkg = 'Catmandu::Importer';
    use_ok $pkg;
}
require_ok $pkg;

{
    package T::Importer;
    use Moo;
    with $pkg;

    sub generator {
        my ($self) = @_;
        sub {
            state $fh = $self->fh;
            my $name = $self->readline;
            return defined $name ? { "hello" => $name } : undef;
        };
    }

    package T::DataPathImporter;
    use Moo;
    with $pkg;

    sub generator {
        my ($self) = @_;
        sub {
            state $data = [{abc => [{a=>1},{b=>2},{c=>3}]},
                           {abc => [{d=>4},{e=>5},{f=>6}]}];
            return shift @$data;
        };
    }
}

my $i = T::Importer->new;
ok $i->does('Catmandu::Iterable');

$i = T::Importer->new( file => \"World" );
is_deeply $i->to_array, [{ hello => "World"}], 'import from string reference';

$i = T::Importer->new( file => \"Hello\nWorld" );
is $i->readall, "Hello\nWorld", "import all";

$i = T::DataPathImporter->new;
is_deeply $i->to_array, [{abc => [{a=>1},{b=>2},{c=>3}]},{abc => [{d=>4},{e=>5},{f=>6}]}];
$i = T::DataPathImporter->new(data_path => 'abc');
is_deeply $i->to_array, [[{a=>1},{b=>2},{c=>3}],[{d=>4},{e=>5},{f=>6}]];
$i = T::DataPathImporter->new(data_path => 'abc.*');
is_deeply $i->to_array, [{a=>1},{b=>2},{c=>3},{d=>4},{e=>5},{f=>6}];

$i = T::Importer->new( user_agent => user_agent() , file => 'http://demo.org/' );
is $i->readall , "test123" , "read from http (file)";

$i = T::Importer->new( user_agent => user_agent() , file => 'http://demo.org/{id}' , variables => { id => 1234} );
is $i->file , "http://demo.org/1234";
is $i->readall , "test1234" , "read from http (file + variables)";

$i = T::Importer->new( user_agent => user_agent() , file => 'http://demo.org/{id}' , variables => { id => [qw(red green blue)]});
is $i->file , "http://demo.org/red,green,blue";
is $i->readall , "RED-GREEN-BLUE" , "read from http (file + variables list)";

done_testing;

sub user_agent  {
    my $ua = Test::LWP::UserAgent->new(agent => 'Test/1.0');

    $ua->map_response(
        qr{^http://demo.org/$},
        HTTP::Response->new(
            '200' ,
            'OK' ,
            [ 'Content-Type' => 'text/plain'] ,
            'test123'
        )
    );

    $ua->map_response(
        qr{^http://demo.org/1234$},
        HTTP::Response->new(
            '200' ,
            'OK' ,
            [ 'Content-Type' => 'text/plain'] ,
            'test1234'
        )
    );

    $ua->map_response(
        qr{^http://demo.org/red,green,blue$},
        HTTP::Response->new(
            '200' ,
            'OK' ,
            [ 'Content-Type' => 'text/plain'] ,
            'RED-GREEN-BLUE'
        )
    );

    $ua;
}

