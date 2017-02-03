package Component::UrbanDictionary;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(define wotd);

use Mojo::UserAgent;
use URI::Encode qw(uri_encode uri_decode);
use Data::Dumper;

# This module can define specific words or retrieve the Word of the Day from Urban Dictionary
# No API Key needed, this one is pretty simple.

sub new
{
    my ($class, %params) = @_;
    my $self = {};
   
    my $api_url = 'http://api.urbandictionary.com/v0';
    my $ua = Mojo::UserAgent->new;
    $ua->connect_timeout(5);

    $self->{'ua'} = $ua;
    $self->{'api_url'} = $api_url;
    
    bless($self, $class); 
    return $self;
}

# Define a word
# Is non-blocking if callback is defined.
sub define
{
    my ($self, $word, $callback) = @_;

    my $ua      = $self->{'ua'};
    my $api_url = $self->{'api_url'};
    my $url     = $api_url . '/define?term=' . uri_encode($word);
    say "URL: $url";

    # Non-blocking if they provided a callback function
    if ( defined $callback )
    {
        $ua->get($url => sub {
            my ($ua, $tx) = @_;
    
            my $json = $tx->res->json;
            
            $callback->($json);
        });
    }

    # Else, this becomes a blocking call.
    return $ua->get($url)->res->json;
}

# Return the word of the day
# This comes from a third party site which just screen-scrapes the UrbanDictionary site and provides
# the Word of the Day in a JSON format.
sub wotd
{
    my ($self, $callback) = @_;

    my $ua = $self->{'ua'};
    my $url = 'https://urban-word-of-the-day.herokuapp.com/today';

    if ( defined $callback )
    {
        $ua->get($url => sub {
            my ($ua, $tx) = @_;

            my $json = $tx->res->json;

            $callback->($json);
        });
    }

    # Else this is a blocking call
    return $ua->get($url)->res->json;
}

1;
