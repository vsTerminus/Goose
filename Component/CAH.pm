package Component::CAH;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(random_black random_white);

use Mojo::UserAgent;
use Data::Dumper;

# This module connects to the CAH Cards local webserver
# While it doesn't need an API Key, you do need to pass in the URL where you've hosted it as "api_url"

sub new
{
    my ($class, %params) = @_;
    my $self = {};
   
    my $api_url = $params{'api_url'};
    my $ua = Mojo::UserAgent->new;
    $ua->connect_timeout(5);

    $self->{'ua'} = $ua;
    $self->{'api_url'} = $api_url;
    
    bless($self, $class); 
    return $self;
}

# Returns a random black card, optionally with the specified number of blanks.
# Pass in undef if you don't care how many blanks.
sub random_black
{
    my ($self, $pick, $callback) = @_;

    my $ua      = $self->{'ua'};
    my $api_url = $self->{'api_url'};
    my $url     = $api_url . '/cards/black/rand';
    $url .= '?pick=' . $pick if defined $pick;

    $ua->get($url => sub {
        my ($ua, $tx) = @_;

        my $json = $tx->res->json;
        
        $callback->($json);
    });
}

# Returns 1 or more random white cards
sub random_white
{
    my ($self, $count, $callback) = @_;

    my $ua = $self->{'ua'};
    my $api_url = $self->{'api_url'};
    my $url = $api_url . '/cards/white/rand';
    $count = 1 if $count < 1;
    $url .= "?count=$count" if defined $count and $count > 1;

    $ua->get($url => sub {
        my ($ua, $tx) = @_;

        my $json = $tx->res->json;

        $callback->($json);
    });
}

1;
