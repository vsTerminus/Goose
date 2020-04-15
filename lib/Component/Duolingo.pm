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
has android_api_url => ( is => 'ro', default => 'https://android-api.duolingo.com/2017-06-30' );
has login_url       => ( is => 'ro', default => 'https://www.duolingo.com/login' );
has leaderboard_url => ( is => 'ro', default => 'https://duolingo-leaderboards-prod.duolingo.com/leaderboards' );
has leaderboard_id  => ( is => 'ro', default => '7D9F5DD1-8423-491A-91F2-2532052038CE' ); # I don't understand the source of this value yet. I got it by sniffing the android app's traffic on two different accounts.
has dict_base_url   => ( is => 'lazy', builder => sub { shift->_dict_base_url_p(); } );
has ua_str_droid    => ( is => 'ro', default => 'Duodroid/4.58.2 Dalvik/2.1.0 (Linux; U; Android 9; Android SDK built for x86_64 Build/PSR1.180720.093)' );
has ua_str_web      => ( is => 'ro', default => 'Mozilla/5.0 (Linux x86_64; rv:75.0) Gecko/20100101 Firefox/75.0' );
has ua              => ( is => 'lazy', builder => sub 
{ 
    my $ua = Mojo::UserAgent->new->with_roles('+Queued');
    $ua->connect_timeout(5);
    $ua->inactivity_timeout(10);
    $ua->max_active(5);

    return $ua;
});
has username        => ( is => 'ro' );
has password        => ( is => 'ro' );
has jwt             => ( is => 'rw' );
has csrf            => ( is => 'rw' );
has user_id         => ( is => 'rw' );
has uri             => ( is => 'lazy', builder => sub { URI::Encode->new });

sub _set_ua
{
    my ($self, $type) = @_;

    if ( $type eq 'android' )
    {
        $self->ua->transactor->name($self->ua_str_droid);
    }
    else
    {
        $self->ua->transactor->name($self->ua_str_web);
    }
}

sub login_p
{
    my ($self) = @_;

    $self->_set_ua('web');
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

                # Extract JWT and CSRF from cookies
                my $jar = $self->ua->cookie_jar;
                foreach my $cookie ( @{$jar->find(Mojo::URL->new($self->login_url) )} )
                {
                    $self->jwt($cookie->value) if $cookie->name eq 'jwt_token';
                    $self->csrf($cookie->value) if $cookie->name eq 'csrf_token';
                }
                
                say "CSRF: " . $self->csrf;
                say "JWT: " . $self->jwt;

                $json->{'csrf'} = $self->csrf;
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

sub load_cookies
{
    my ($self, $cookie_file) = @_;

    $self->_set_ua('web');
    die("Invalid cookie file") unless -f $cookie_file;

    my $ua = $self->ua;
    my $cookie_jar = $ua->cookie_jar;
    $cookie_jar->with_roles('+Persistent')->file($cookie_file);
    $cookie_jar->load;

    foreach my $cookie ( @{$cookie_jar->find(Mojo::URL->new($self->login_url) )} )
    {
        $self->jwt($cookie->value) if $cookie->name eq 'jwt_token';
        $self->csrf($cookie->value) if $cookie->name eq 'csrf_token';
    }

    return $self->jwt;
}

sub _dict_base_url_p
{
    my ($self) = @_;

    $self->_set_ua('web');
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

    $self->_set_ua('web');
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

    $self->_set_ua('web');
    my $promise = Mojo::Promise->new;

    $self->version_info(sub
    {
        my $json = shift;
        $promise->resolve($json);
    });

    return $promise;
}

sub android_user_info
{
    my ($self, $id, $callback) = @_;

    $self->_set_ua('android');
    say "user_info for '$id'";
    return unless defined $id;
    return unless defined $callback and ref $callback eq 'CODE';

    # Need ID. Can convert if username.
    if ($id !~ /^\d+$/)
    {
        $self->user_id_p($id)->then(sub
        {
            $self->android_user_info(shift, $callback); # Call this sub again when we have the ID.
        })->catch(sub
        {
            $callback->(shift);
        });
        return;
    }

    # If we're here we have an ID
    my $fields = 'name,username,streak,streakData,xpGoal,timezone,trackingProperties,id,picture,totalXp,currentCourseId,courses{authorId,fromLanguage,id,healthEnabled,learningLanguage,preload,title,xp,crowns}';
    my $url = $self->android_api_url . '/users/' . $id . '?fields=' . $fields;

    say "URL: $url";

    $self->ua->get($self->uri->encode($url) => sub
    {
        my ($ua, $tx) = @_;

        $callback->($tx->res->json) if defined $callback;
    });
}

sub android_user_info_p
{
    my ($self, $user) = @_;

    $self->_set_ua('android');
    my $promise = Mojo::Promise->new;

    $self->android_user_info($user, sub
    {
        $promise->resolve(shift);
    });

    return $promise;
}

# Takes a user ID or a user name, returns the web version of the profile.
sub web_user_info_p
{
    my ($self, $user) = @_;

    $self->_set_ua('web');
    my $promise = Mojo::Promise->new;

    my $url = $self->api_url . '/users/show?username=' . $user;
    $url = $self->api_url . '/users/show?id=' . $user if ($user =~ /^\d+$/);

    say "URL: " . $url;
    $self->ua->get_p($url)->then(sub
    {
        my $tx = shift;
        $promise->resolve($tx->res->json);
    })->catch(sub
    {
        $promise->reject(shift->error);
    });

    return $promise;

}

# Takes a username, gives back a user id via promise
sub user_id_p
{
    my ($self, $username) = @_;

    my $promise = Mojo::Promise->new;

    $self->web_user_info_p($username)->then(sub
    {
        my $json = shift;
        my $id = $json->{'id'};
        $id ? $promise->resolve($id) : $promise->reject("Could not find a 'id' field in JSON response");
    })->catch(sub{ $promise->reject(shift->error) });

    return $promise;
}

sub leaderboard_p
{
    my ($self, $user_id) = @_;

    $self->_set_ua('android');
    my $promise = Mojo::Promise->new;

    # Need ID. Can convert if username.
    if ($user_id !~ /^\d+$/)
    {
        $self->user_id_p($user_id)->then(sub
        {
            $self->leaderboard_p(shift)->then(sub{$promise->resolve(shift)});
        });

    }
    else
    {
        my $url = $self->leaderboard_url . '/' . $self->leaderboard_id . '/users/' . $user_id . '?client_unlocked=true';
        
        say "URL: $url";

        $self->ua->get_p($url)->then(sub
        {
            $promise->resolve(shift->res->json);
        })->catch(sub
        {
            $promise->reject(shift->error);
        });
    }

    return $promise;
}

# Return a human readable league name
sub league_p
{
    my ($self, $id) = @_;

    my @tiers = qw(Bronze Silver Gold Sapphire Ruby Emerald Amethyst Pearl Obsidian Diamond);

    my $promise = Mojo::Promise->new;

    $self->leaderboard_p($id)->then(sub
    {
        my $json = shift;
        my $tier = $json->{'tier'};
        my $league = $tiers[$tier];
        say "Tier $tier -> $league League";

        $promise->resolve($league);
    });
}

sub follow_p
{
    my ($self, $follow_id, $subs) = @_;

    $self->_set_ua('android');
    my $promise = Mojo::Promise->new;

    my $url = $self->android_api_url . '/users/' . $self->user_id . '/subscriptions/' . $follow_id . '?csrfToken=' . $self->csrf;
    print "URL: $url\n";

    $self->ua->put_p($url)->then(sub{ $promise->resolve(shift->res->json) })->catch(sub{ $promise->reject(shift->error) });

    return $promise;
}

sub unfollow_p
{
    my ($self, $follow_id, $subs) = @_;

    $self->_set_ua('android');
    my $promise = Mojo::Promise->new;

    my $url = $self->android_api_url . '/users/' . $self->user_id . '/subscriptions/' . $follow_id . '?csrfToken=' . $self->csrf;
    print "URL: $url\n";

    $self->ua->delete_p($url)->then(sub{ $promise->resolve(shift->res->json) })->catch(sub{ $promise->reject(shift->error) });

    return $promise;
}




1;
