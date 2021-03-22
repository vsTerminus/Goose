package Component::Peeled;

use feature 'say';
use Moo;
use strictures 2;

use Mojo::UserAgent;
use Mojo::Promise;
use Mojo::URL;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(peel);

has api_url => ( is => 'ro', required => 1 );
has ua          => ( is => 'rw', builder => sub { 
        my $ua = Mojo::UserAgent->new;
        $ua->connect_timeout(5);
        $ua->inactivity_timeout(120);
        return $ua;
    });
has cache       => ( is => 'rw', default => sub { {} } );

# The API does not have a key, which is why I am putting it in a config variable only.
# The expected return looks like (in case you want to implement your own):
#
# {
#   "dex_no": 269,
#   "image_url": "https://pbs.twimg.com/media/Em_kPTmWEAg7BgF.png",
#   "tweet_url": "https://twitter.com/i/status/1328531387691970560"
# }
#
# 404 if not found.

# Takes a pokemon name as a string
sub peel
{
    my ($self, $pokestr) = @_;
    $pokestr = lc $pokestr;

    my $promise = Mojo::Promise->new();

    unless ( defined $pokestr and length $pokestr > 1 and length $pokestr < 50 )
    {
        $promise->reject( { 'error' => 'invalid pokemon name value. Expect string between 1 and 50 characters.' } );
        return $promise;
    }
    unless ( defined $self->api_url and $self->api_url =~ /^http/ )
    {
        $promise->reject( { 'error' => 'invalid API URL (' . $self->api_url . ')' } );
        return $promise;
    }

    $promise->resolve( $self->cached($pokestr) // $self->fetch($pokestr) );
    return $promise;
}

sub cached
{
    my ($self, $pokestr) = @_;

    return $self->cache->{lc $pokestr} // undef;
}

sub fetch
{
    my ($self, $pokestr) = @_;

    my $promise = Mojo::Promise->new();
   
    my $url = Mojo::URL->new($self->api_url);
    $url->query(name => $pokestr);

    $promise = $self->ua->get_p($url)->then(sub
        {
            my $tx = shift;
            unless ( $tx->res->code == 200 )
            {
                my $error = { 'code' => $tx->res->code, 'error' => 'Pokemon does not exist or has not yet been peeled' };
                $promise->reject($error);
                return $promise;
            }
            
            my $json = $tx->res->json;

            # Cache the results indefinitely
            $self->cache->{lc $pokestr} = $json;

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
