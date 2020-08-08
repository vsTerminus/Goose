package Command::Goal;;
use feature 'say';

use Moo;
use strictures 2;

use Command::Goal::Horns;

use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_template);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );
has horns               => ( is => 'lazy', builder => sub { Command::Goal::Horns->new });

has name                => ( is => 'ro', default => 'Goal' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'Goal Horns for different teams' );
has pattern             => ( is => 'ro', default => '^goal ?' );
has function            => ( is => 'ro', default => sub { \&cmd_goal } );
has usage               => ( is => 'ro', default => <<EOF
Link the goal horn for different teams

Basic Usage: !template <three letter team code>
Eg: `!goal AHA` or `!goal BOS`
EOF
);

sub cmd_goal
{
    my ($self, $msg) = @_;

    my $channel = $msg->{'channel_id'};
    my $author = $msg->{'author'};

    my $args = $msg->{'content'};
    
    my $pattern = $self->pattern;
    $args =~ s/$pattern//i;
        
    my $link = $self->horns->horn($args);
    if ( $link )
    {
        $self->discord->send_message($channel, ":rotating_light: GOAL!!! :rotating_light:\n" . $link);
    }
    else
    {
        my @teams = $self->horns->teams();
        $self->discord->send_message($channel, "Available teams: @teams"); 
    }
}

1;
