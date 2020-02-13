package Command::Leave;
use feature 'say';

use Moo;
use strictures 2;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_guilds);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );

has name                => ( is => 'ro', default => 'Leave' );
has access              => ( is => 'ro', default => 1 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'Leave a discord guild' );
has pattern             => ( is => 'ro', default => '^leave ?' );
has function            => ( is => 'ro', default => sub { \&cmd_leave } );
has usage               => ( is => 'ro', default => <<EOF
Basic Usage: `!leave <guild id>`
EOF
);

sub cmd_leave
{
    my ($self, $msg) = @_;

    my $channel = $msg->{'channel_id'};
    my $author = $msg->{'author'};
    my $args = $msg->{'content'};

    my $discord = $self->discord;
    my $pattern = $self->pattern;
    $args =~ s/$pattern//i;

    
    my $user = '@me';
    $discord->send_message($channel, "Attempting to Leave Guild: `$args`");
    $discord->leave_guild($user, $args);
}

1;
