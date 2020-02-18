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

    my $channel = $msg->{'channel_id'};
    my $author = $msg->{'author'};

    my $args = $msg->{'content'};
    
    my $pattern = $self->pattern;
    $args =~ s/$pattern//;

    $self->duo->get_user_info_p($args)->then(sub
    {
        my $json = shift;
        my $content = $self->_build_message($json);     # Pull out certain fields and format it for Discord

        if (my $hook = $self->bot->has_webhook($channel) )
        {
            my $message = {
                'content' => $content,
                'embeds' => undef,
                'username' => $json->{'fullname'},
                'avatar_url' => $json->{'avatar'},
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

sub _build_message
{
    my ($self, $json) = @_;

    $self->bot->log->debug($json);

    my $lang_abbr = $json->{'learning_language'};
    my $lang_data = $json->{'language_data'}{$lang_abbr};

    say "Learning: " . $lang_abbr . " " . $json->{'learning_language_string'};
    say "Level: " . $lang_data->{'level'};
    say "Next: " . $lang_data->{'next_lesson'}{'skill_title'};
    say "Streak: " . $lang_data->{'streak'};
    say "Extended: " . $json->{'streak_extended_today'};

    my $msg = "```\n" .
    "Learning:       " . $json->{'learning_language_string'} . "\n" .
    "Level:          " . $lang_data->{'level'} . "\n" .
    "Next Lesson:    " . $lang_data->{'next_lesson'}{'skill_title'} . "\n" .
    "Current Streak: " . $lang_data->{'streak'} . "\n```\n\n";

    ( $json->{'streak_extended_today'} ) ? $msg .= "Streak extended today!" : $msg .= "Streak has not been extended yet today.";

    return $msg;
}



1;
