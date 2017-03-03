package Component::Twitch;

use Exporter qw(import);
our @EXPORT_OK = qw(search);

use Mojo::Base -base;
use Mojo::UserAgent;
use URI::Escape;
use Data::Dumper;

# This component integrates with the Twitch v5 API

has 'api_key';
has api_url => 'https://api.twitch.tv/kraken';
has ua      => sub { Mojo::UserAgent->new };

# Search Channels, Streams, or Games
# Is non-blocking if a callback is provided
sub search
{
    my ($self, $type, $q, $callback) = @_;

    if ( $type !~ /^channels|games|streams$/i )
    {
        return undef; # Unknown
    }

    # Else, type is good.
    my $url = $self->api_url . '/search/' . lc $type . '?query=' . uri_escape_utf8($q) . '&limit=10&client_id=' . $self->api_key;

    if ( defined $callback )    # Non-Blocking
    {
        $self->ua->get($url => {'Accept' => 'application/vnd.twitchtv.v5+json'} => sub
        {
            my ($ua, $tx) = @_;

            my $json = $tx->res->json;

            $callback->($json);
        });
    }
    else    # Blocking
    {
        return $self->ua->get($url => {'Accept' => 'application/vnd.twitchtv.v5+json'})->res->json;
    }

}

# Get Channel Info by Twitch Username (More accurate than search)
# Is non-blocking if callback is provided
sub get_channel
{
    my ($self, $id, $callback) = @_;

    my $url = $self->api_url . '/channels/' . $id . '?client_id=' . $self->api_key;
    
    if ( defined $callback) # Non-Blocking
    {
        $self->ua->get($url => {'Accept' => 'application/vnd.twitchtv.v5+json'} => sub
        {
            my ($ua, $tx) = @_;
            my $json = $tx->res->json;

            #say Dumper($json);

            $callback->($json);
        });
    }
    else    # Blocking
    {
        return $self->ua->get($url => {'Accept' => 'application/vnd.twitchtv.v5+json'})->res->json;
    }
}

# Get Stream Info by Twitch Username
# Is non-blocking if callback is provided
sub get_stream
{
    my ($self, $id, $callback) = @_;

    my $url = $self->api_url . '/streams/' . $id . '?client_id=' . $self->api_key;
    
    if ( defined $callback) # Non-Blocking
    {
        $self->ua->get($url => {'Accept' => 'application/vnd.twitchtv.v5+json'} => sub
        {
            my ($ua, $tx) = @_;
            my $json = $tx->res->json;

            $callback->($json);
        });
    }
    else    # Blocking
    {
        return $self->ua->get($url => {'Accept' => 'application/vnd.twitchtv.v5+json'})->res->json;
    }
}



1;


1;
