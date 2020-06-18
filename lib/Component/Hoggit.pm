package Component::Hoggit;

use feature 'say';
use Moo;
use strictures 2;

use Carp;
use Mojo::UserAgent;
use Mojo::Promise;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(weather);

has server_urls => ( is => 'ro', default => sub {
    {
        'pgaw'  => 'https://pgaw.hoggitworld.com',
        'gaw'   => 'https://dcs.hoggitworld.com',
    }
});
has ua          => ( is => 'rw', builder => sub { 
        my $ua = Mojo::UserAgent->new;
        $ua->connect_timeout(5);
        $ua->inactivity_timeout(120);
        return $ua;
    });
has cache       => ( is => 'rw', default => sub { {} } );


# Return the entire JSON message
sub server_info_p
{
    my ($self, $server) = @_; # Accepts 'pgaw' or 'gaw', does nothing if undef

    $server = lc $server;

    unless (defined $server and ($server eq 'pgaw' or $server eq 'gaw'))
    {
        carp '$server is undefined. Expected "gaw" or "pgaw".';
        return;
    }
    my $url = $self->server_urls->{$server};
    my $promise = Mojo::Promise->new;

    if ( exists $self->cache->{$server} and time < $self->cache->{$server}{'expires'} )
    {
        $promise->resolve($self->cache->{$server}{'json'});
        return $promise;
    }

    $promise = $self->ua->get_p($url)->then(sub
        {
            my $tx = shift;
            my $json = $tx->res->json;

            # Cache for 1 minute
            $self->cache->{$server}{'json'} = $json;
            $self->cache->{$server}{'expires'} = time+60;

            $promise->resolve($json);
        }
    )->catch(sub
        {
            my $err = shift;
            $promise->resolve($err);
        }
    );

    return $promise;
}

1;
