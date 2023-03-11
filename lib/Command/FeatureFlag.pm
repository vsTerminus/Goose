package Command::FeatureFlag;
use feature 'say';

use Moo;
use Switch;
use Data::Dumper;
use strictures 2;

use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_featureflag);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );
has ff                  => ( is => 'lazy', builder => sub { shift->bot->ff; } );

has name                => ( is => 'ro', default => 'FeatureFlag' );
has access              => ( is => 'ro', default => 1 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'Dynamically enable or disable specific bot features' );
has pattern             => ( is => 'ro', default => '^(feature|featureflag|flag|ff) ?' );
has function            => ( is => 'ro', default => sub { \&cmd_ff } );
has usage               => ( is => 'ro', default => <<EOF
This command allows the bot owner to toggle any functionality within the bot that has been wrapped in a defined feature flag.

Usage: !ff <enable|disable|create|delete|get> <flag name>
EOF
);

sub cmd_ff
{
    my ($self, $msg) = @_;

    my $channel = $msg->{'channel_id'};
    my $author = $msg->{'author'};

    my $args = $msg->{'content'};
    # "$args" contains the command and the arguments the user typed.
    # Most of the time we'll want to strip the command out of $msg and just look at the arguments.
    # You can use $self->pattern to do this.
    
    my $pattern = $self->pattern;
    $args =~ s/$pattern//i;
    
    # Data::Dumper is an easy way to dump any variable, including complex structures, to debug your command. 
    # You can send its output to the screen or to log files or both.
    # $self->bot->log->debug('[FeatureFlag.pm] [cmd_ff] ' . Data::Dumper->Dump([$msg], ['msg']));
    # say Data::Dumper->Dump([$args], ['args']);

    # You know the channel the message came from and who sent it.
    # You can use that information to tailor your reply (eg, mention the user or not, look up other info on them, etc)
    # my $reply = ( length $args ? "Your message was:\n```\n$args\n```" : "Your Discord ID is: " . $author->{'id'} );

    # Send a message back to the channel
    #$self->discord->send_message($channel, $reply);
    
    if ( $args =~ /^create ([a-zA-Z0-9_-]+)$/ )
    {
        my $flag_name = lc $1;
        $self->log->info('[FeatureFlag.pm] [cmd_ff] Creating feature flag: ' . $flag_name);
        my $msg = ( $self->ff->create_flag($flag_name) ? ":white_check_mark: Created '$flag_name'" : ":x: Could not create the flag" );
        $self->discord->send_message($channel, $msg);
    }
    elsif ( $args =~ /^delete ([a-zA-Z0-9_-]+)$/ )
    {
        my $flag_name = lc $1;
        $self->log->info('[FeatureFlag.pm] [cmd_ff] Deleting feature flag: ' . $flag_name);
        my $msg = ( $self->ff->delete_flag($flag_name) ? ":white_check_mark: Deleted '$flag_name'" : ":x: Could not delete the flag" );
        $self->discord->send_message($channel, $msg);
    }
    elsif ( $args =~ /^enable ([a-zA-Z0-9_-]+)$/ )
    {
        my $flag_name = lc $1;
        $self->log->info('[FeatureFlag.pm] [cmd_ff] Enabling feature flag: ' . $flag_name);
        my $msg = ( $self->ff->enable_flag($flag_name) ? ":ballot_box_with_check: Enabled '$flag_name'" : ":x: Flag does not exist" );
        $self->discord->send_message($channel, $msg);
    }
    elsif ( $args =~ /^disable ([a-zA-Z0-9_-]+)$/ )
    {
        my $flag_name = lc $1;
        $self->log->info('[FeatureFlag.pm] [cmd_ff] Disabling feature flag: ' . $flag_name);
        my $msg = ( $self->ff->disable_flag($flag_name) ? ":no_entry: Disabled '$flag_name'" : ":x: Flag does not exist" );
        $self->discord->send_message($channel, $msg);
        
    }
    elsif ( $args =~ /^get ([a-zA-Z0-9_-]+)$/ )
    {
        my $flag_name = lc $1;
        my $flag_value = $self->ff->get_flag($flag_name);
        my $msg;
        switch($flag_value)
        {
            case -1 { $msg = ":x: Flag does not exist" }
            case 0 { $msg = ":no_entry: Flag is currently disabled" }
            case 1 { $msg = ":ballot_box_with_check: Flag is currently enabled" }
        }
        $self->discord->send_message($channel, $msg);

    }
    elsif ( $args =~ /^list/ )
    {
        my $flag_list = $self->ff->list_flags();
        my @all = map {@$_} @{$flag_list};
        $self->discord->send_message($channel, ":notepad_spiral: All Feature Flags: @all");
    }
    else
    {
        $self->discord->send_message($channel, "Usage: `!ff <enable|disable|create|delete|get> <flag_name>` or `!ff list`. Flag name may contain letters, numbers, dashes, and underscores.");
    }
}

1;
