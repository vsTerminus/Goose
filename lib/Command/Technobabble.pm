package Command::Technobabble;
use feature 'say';
use utf8;

use Moo;
use strictures 2;
use Command::Technobabble::Content;
use Math::Random::Secure qw(irand);
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_technobabble);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );
has content             => ( is => 'lazy', builder => sub { Command::Technobabble::Content->new } );

has name                => ( is => 'ro', default => 'Technobabble' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'Would you like to encrypt the central pulsating mainframe to enhance the interdimensional network?' );
has pattern             => ( is => 'ro', default => '^(technobabble|babble|startrek|trek)' );
has function            => ( is => 'ro', default => sub { \&cmd_technobabble } );
has usage               => ( is => 'ro', default => <<EOF
`!technobabble`

Also accepts `!babble`, `!startrek`, and `!trek`
EOF
);

sub cmd_technobabble
{
    my ($self, $msg) = @_;

    my $channel_id = $msg->{'channel_id'};

    my $babble = $self->_random();
    $self->discord->send_message($channel_id, $babble);
}

sub _random
{
    my ($self) = shift;

    # Logic blatantly stolen and modified from https://www.scifiideas.com/js/technobabble-generator.js

    my $math            = Math::Expression->new();

    my $final;
    my $typeChance      = irand(100);

    if ( $typeChance < 30 )
    {
        $final = $self->_randomTask();
    }
    elsif ( $typeChance > 30 and $typeChance < 60 )
    {
        $final = $self->_randomOffline() . ' ' . $self->_randomTask();
    }
    else
    {
        $final = $self->_randomProblem();

        if ( irand(100) > 50 )
        {
            $final .= ' ' . $self->_randomProblemTask();
        }
    }

    return $final;
}

sub _randomString
{
    my ($self, $content) = @_;
    my $size = scalar @{$content};
    return $content->[irand($size)];
}

sub _randomTask
{
    my $self = shift;
 
    my $randomWho       = $self->_randomString($self->content->who);
    my $randomTodoVerb  = $self->_randomString($self->content->todoVerb);
    my $randomThingAdj  = $self->_randomString($self->content->thingAdj);
    my $randomThingDesc = $self->_randomString($self->content->thingDesc);
    my $randomThing     = $self->_randomString($self->content->thing);

    return $randomWho . ' ' . $randomTodoVerb . ' the ' . $randomThingAdj . ' ' . $randomThingDesc . ' ' . $randomThing . '.';
}

sub _randomOffline
{
    my $self = shift;

    my $randomThingAdj  = $self->_randomString($self->content->thingAdj);
    my $randomThingDesc = $self->_randomString($self->content->thingDesc);

    return 'The ' . $randomThingAdj . ' ' . $randomThingDesc . ' is offline.'
}

sub _randomProblem
{
    my $self = shift;

    my $randomProblemStart  = $self->_randomString($self->content->problemStart);
    my $randomProblem       = $self->_randomString($self->content->problem);
    my $randomThingAdj      = $self->_randomString($self->content->thingAdj);
    my $randomThingDesc     = $self->_randomString($self->content->thingDesc);
    my $randomThing         = $self->_randomString($self->content->thing);

    return $randomProblemStart . ' ' . $randomProblem . ' in the ' . $randomThingAdj . ' ' . $randomThingDesc . ' ' . $randomThing . '.';
}

sub _randomProblemTask
{
    my $self = shift;

    my $randomWho       = $self->_randomString($self->content->who);
    my $randomTodoVerb  = $self->_randomString($self->content->todoVerb);
    my $randomThingDesc = $self->_randomString($self->content->thingDesc);
    my $randomThing     = $self->_randomString($self->content->thing);

    return $randomWho . ' ' . $randomTodoVerb . ' the ' . $randomThingDesc . ' ' . $randomThing . '.';
}

1;
