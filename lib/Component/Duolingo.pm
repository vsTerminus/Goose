package Component::Duolingo;

use feature 'say';
use Moo;
use strictures 2;

use Mojo::UserAgent;
use Mojo::Promise;
use URI::Encode;
use Data::Dumper;
use namespace::clean;

has api_url         => ( is => 'ro', default => 'https://www.duolingo.com/api/1' );
has login_url       => ( is => 'ro', default => 'https://www.duolingo.com/login' );
has leaderboard_url => ( is => 'ro', default => 'https://www.duolingo.com/friendships/leaderboard_activity' );
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
has uri             => ( is => 'lazy', builder => sub { URI::Encode->new });

sub login_p
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


sub user_info
{
    my ($self, $user, $callback) = @_;

    say "user_info for '$user'";
    return undef unless defined $user;

    my $url = $self->api_url;

    # Accept ID or Username.
    $url .= ( $user =~ /^\d+$/ ? '/users/show?id=' . $user : '/users/show?username=' . $user );

    say "URL: $url";

    $self->ua->get($url => sub
    {
        my ($ua, $tx) = @_;

        $callback->($tx->res->json) if defined $callback;
    });
}

sub user_info_p
{
    my ($self, $user) = @_;

    my $promise = Mojo::Promise->new;

    $self->user_info($user, sub
    {
        $promise->resolve(shift);
    });

    return $promise;
}

sub leaderboard
{
    my ($self, $unit, $before, $callback) = @_;

    # Unit can be week or month
    # before is a datetime in format '2015.07.06 05:42:24'

    my $url = $self->leaderboard_url . '?unit=' . $unit . '&_=' . $before;
    
    say "URL: $url";
    say "Encoded URL: " . $self->uri->encode($url);

    $self->ua->get( $self->uri->encode($url) => sub
    {
        my ($ua, $tx) = @_;

        if ( $tx->result )
        {
            say "Result";
            $callback->($tx->res->json) if defined $callback;
        }
        elsif ( my $err = $tx->error )
        {
            say "Error";
            $callback->($err) if defined $callback;
        }
        else
        {
            say "Else?";
        }
    });
}

sub leaderboard_p
{
    my ($self, $unit, $before) = @_;

    my $promise = Mojo::Promise->new;

    $self->leaderboard($unit, $before, sub
    {
        $promise->resolve(shift);
    });

    return $promise;
}

1;
