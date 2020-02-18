package Component::Duolingo;

use feature 'say';
use Moo;
use strictures 2;

use Mojo::UserAgent;
use Mojo::Promise;
use Data::Dumper;
use namespace::clean;

has api_url         => ( is => 'ro', default => 'https://www.duolingo.com/api/1' );
has login_url       => ( is => 'ro', default => 'https://www.duolingo.com/login' );
has dict_base_url   => ( is => 'lazy', builder => sub { shift->_dict_base_url_p(); } );
has ua              => ( is => 'lazy', builder => sub 
{ 
    my $ua = Mojo::UserAgent->new;
    $ua->connect_timeout(5);
    $ua->inactivity_timeout(120);
    return $ua;
});
has username        => ( is => 'ro' );
has password        => ( is => 'ro' );
has jwt             => ( is => 'rw' );
has user_id         => ( is => 'rw' );

sub _login_p
{
    my ($self) = @_;

    my $promise = Mojo::Promise->new;
    my $url = $self->login_url;
    say "Login URL: $url";

    $self->ua->post_p($url => json =>
        {
            login       => $self->username,
            password    => $self->password,
        }
    )->then(sub
        {
            my $tx = shift;
            my $json = $tx->res->json;
            my $headers = $tx->res->headers;
            if ( $json->{'response'} eq 'OK' )
            {
                $self->user_id($json->{'user_id'});
                $self->jwt($headers->header('jwt'));

                say "Login OK. User_id: " . $self->user_id;
                say "JWT: " . $self->jwt;
                $json->{'jwt'} = $self->jwt;
                $promise->resolve($json);
            }
            else
            {
                $promise->resolve($json);
            }
        }
    )->catch(sub
        {
            my $err = shift;
            $promise->resolve($err);
        }
    );

    return $promise;
}

sub _dict_base_url_p
{
    my ($self) = @_;

    my $promise = Mojo::Promise->new;

    $self->version_info_p()->then(sub
    { 
        my $json = shift;
        my $url = $json->{'dict_base_url'}; 

        #        $self->dict_base_url($url);
        $promise->resolve($url);
    });

    return $promise;
}

# This is required to get the dict_base_url
sub version_info
{
    my ($self, $callback) = @_;

    my $url = $self->api_url . '/version_info';

    $self->ua->get($url => sub
    {
        my ($ua, $tx) = @_;
        #        say Dumper($tx->res->json);
        $callback->($tx->res->json) if defined $callback;
    });
}

sub version_info_p
{
    my ($self) = @_;

    my $promise = Mojo::Promise->new;

    $self->version_info(sub
    {
        my $json = shift;
        $promise->resolve($json);
    });

    return $promise;
}


sub get_user_info
{
    my ($self, $user, $callback) = @_;

    # Be smarter... decode the token and look at the expiry time before getting a new one.
    my $json;
    $self->_login_p()->then(sub
    {
        my $url = $self->api_url . '/users/show?username=' . $user;

        $self->ua->get($url => sub
        {
            my ($ua, $tx) = @_;

            $callback->($tx->res->json) if defined $callback;
        });
    });
}

sub get_user_info_p
{
    my ($self, $user) = @_;

    my $promise = Mojo::Promise->new;

    $self->get_user_info($user, sub
    {
        $promise->resolve(shift);
    });

    return $promise;
}

1;
