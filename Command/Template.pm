package Command::Template;
use feature 'say';

use Moo;
use strictures 2;

use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_template);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );

has name                => ( is => 'ro', default => 'Template' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'Template Sample Command' );
has pattern             => ( is => 'ro', default => '^tem(?:plate)? ?' );
has function            => ( is => 'ro', default => sub { \&cmd_template } );
has usage               => ( is => 'ro', default => <<EOF
This is a template command to demonstrate how to build your own or to use as a starting point.

Basic Usage: !template
Advanced Usage: !template <your message>
EOF
);

sub cmd_template
{
    my ($self, $channel, $author, $msg) = @_;

    # "$msg" contains the command and the arguments the user typed.
    # Most of the time we'll want to strip the command out of $msg and just look at the arguments.
    # You can use $self->pattern to do this.
    my $args = $msg;
    my $pattern = $self->pattern;
    $args =~ s/$pattern//;
    
    # Data::Dumper is an easy way to dump any variable, including complex structures, to debug your command. 
    # You can send its output to the screen or to log files or both.
    $self->bot->log->debug('[Template.pm] [cmd_template] ' . Data::Dumper->Dump([$msg], ['msg']));
    say Data::Dumper->Dump([$args], ['args']);

    # You know the channel the message came from and who sent it.
    # You can use that information to tailor your reply (eg, mention the user or not, look up other info on them, etc)
    my $reply = ( length $args ? "Your message was:\n```\n$args\n```" : "Your Discord ID is: " . $author->{'id'} );

    # Send a message back to the channel
    $self->discord->send_message($channel, $reply);
}

1;
