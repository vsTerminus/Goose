package Command::Duolingo;
use feature 'say';

use Moo;
use strictures 2;

use Component::Duolingo;
use Mojo::Promise;
use Data::Dumper;

use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_template);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );
has duo                 => ( is => 'lazy', builder => sub { shift->bot->duolingo } );
has db                  => ( is => 'lazy', builder => sub { shift->bot->db } );

has name                => ( is => 'ro', default => 'Duolingo' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'Look up Duolingo profile information' );
has pattern             => ( is => 'ro', default => '^duo(?:lingo)? ?' );
has function            => ( is => 'ro', default => sub { \&cmd_duolingo } );
has usage               => ( is => 'ro', default => <<EOF
Look up user profile information on Duolingo

Set your username: !duo set <your duolingo username>

Get your own info: !duo
Get someone else's info: !duo <duolingo username>
EOF
);

sub cmd_duolingo
{
    my ($self, $msg) = @_;

    # Check for login
    unless ( $self->duo->jwt )
    {
        $self->duo->login_p()->then(sub{ $self->cmd_duolingo($msg) });
        return undef;
    }


    my $channel = $msg->{'channel_id'};
    my $author = $msg->{'author'};

    my $args = $msg->{'content'};
    
    my $pattern = $self->pattern;
    $args =~ s/$pattern//;

    my $duo_user;

    # !duo
    if ( length $args == 0 )
    {
        # Stored ID
        if ( my $duo_id = $self->_get_stored_id($author->{'id'}) )
        {
            $self->log->debug('[Duolingo.pm] [cmd_duolingo] Found stored Duolingo ID (' . $duo_id . ') for Discord ID ' . $author->{'id'});
            say "Found stored ID: " . $duo_id;
            $duo_user = $duo_id;
        }
        # Not stored
        else
        {
            $self->discord->send_message($channel, "Sorry, I don't have your duolingo username on file.");
            $self->discord->send_dm($author->{'id'}, <<EOF
To set your Duolingo username use the following command: `!duo set <your username>`

For example, `!duo set TheLegend27`

You can do that here or in a public channel. Once set you'll be able to use `!duo`.
EOF
);
        }
    }
    # !duo set <username>
    elsif ( $args =~ /^set (.+)$/ )
    {
        say "Setting Duolingo username: " . $1;
        $self->duo->user_info_p($1)->then(sub
        {
            my $json = shift;
            my $duo_id = $json->{'id'};

            $self->db->query('INSERT INTO duolingo VALUES ( ?, ? )', $author->{'id'}, $duo_id);
            $self->discord->send_message($channel, "Your Duolingo account info has been updated.");
        });
    }
    else
    {
        $duo_user = $args;
    }

    # We have a username/id, whether it was stored or passed
    if ( defined $duo_user )
    {
        say '$duo_user is ' . $duo_user;
        $self->duo->user_info_p($duo_user)->then(sub
        {
            my $json = shift;
            $self->log->debug(Dumper($json));
            my $content = $self->_build_message($json);     # Pull out certain fields and format it for Discord

            if (my $hook = $self->bot->has_webhook($channel) )
            {
                my $message = {
                    'content' => $content,
                    'username' => $json->{'fullname'},
                    'avatar_url' => 'http://i.imgur.com/EdGBXeW.png', # Duolingo owl
                };

                $self->discord->send_webhook($channel, $hook, $message);
            }
            else
            {
                my $message = $content;
                $self->discord->send_message($channel, $message);
            }
        });
    }
}

sub _build_message
{
    my ($self, $json) = @_;

    #    $self->log->debug($json);

    my $lang_abbr = $json->{'learning_language'};
    my $lang_data = $json->{'language_data'}{$lang_abbr};

    say "Learning: " . $lang_abbr . " " . $json->{'learning_language_string'};
    say "Level: " . $lang_data->{'level'};
    say "Next: " . $lang_data->{'next_lesson'}{'skill_title'};
    say "Streak: " . $lang_data->{'streak'};
    say "Extended: " . $json->{'streak_extended_today'};

    my $msg = ":flag_" . $lang_abbr . ": " . $json->{'learning_language_string'} . " - " . $lang_data->{'streak'} . " day";
    $msg .= "s" if $lang_data->{'streak'} != 1;
    $msg .= "! :fire:" if $json->{'streak_extended_today'}; # Fire emoji if streak extended today
    $msg .= "\nLevel " . $lang_data->{'level'} . " - " . $lang_data->{'next_lesson'}{'skill_title'};

    return $msg;
}

sub _get_stored_id
{
    my ($self, $discord_id) = @_;

    say "Looking up Duo ID for Discord ID " . $discord_id;
    my $query = $self->db->query('SELECT * from duolingo where discord_id = ?', $discord_id);
   
    if ( my $row = $query->fetchrow_hashref )
    {
        say Dumper($row);
        return $row->{'duolingo_id'};
    }
    return undef;
}



1;
