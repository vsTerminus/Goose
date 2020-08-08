package Command::Goal::Horns;

use Moo;
use strictures 2;

use namespace::clean;

# Teams and links provided by NYVideoGameFreak. Thanks John!
has horns   => ( is => 'ro', default => sub {
    {
        'ANA' => 'https://www.youtube.com/watch?v=6OejNXrGkK0',
        'ARI' => 'https://www.youtube.com/watch?v=RbUxSPoU9Yg',
        'BOS' => 'https://www.youtube.com/watch?v=DsI0PgWADks',
        'BUF' => 'https://www.youtube.com/watch?v=hjFTd3MJOHc',
        'CAR' => 'https://www.youtube.com/watch?v=3exZm6Frd18',
        'CGY' => 'https://www.youtube.com/watch?v=sn1PliBCRDY',
        'CHI' => 'https://www.youtube.com/watch?v=sBeXPMkqR80',
        'CBJ' => 'https://www.youtube.com/watch?v=6yYbQfOWw4k',
        'COL' => 'https://www.youtube.com/watch?v=MARxzs_vCPI',
        'DAL' => 'https://www.youtube.com/watch?v=Af8_9NP5lyw',
        'DET' => 'https://www.youtube.com/watch?v=JflfvLvY7ks',
        'EDM' => 'https://www.youtube.com/watch?v=xc422k5Tcqc',
        'FLA' => 'https://www.youtube.com/watch?v=Dm1bjUB9HLE',
        'LAK' => 'https://www.youtube.com/watch?v=jSgd3aIepY4',
        'MIN' => 'https://www.youtube.com/watch?v=4Pj8hWPR9VI',
        'MTL' => 'https://www.youtube.com/watch?v=rRGlUFWEBMk',
        'NSH' => 'https://www.youtube.com/watch?v=fHTehdlMwWQ',
        'NJD' => 'https://www.youtube.com/watch?v=4q0eNg-AbrQ',
        'NYI' => 'https://www.youtube.com/watch?v=i-XY8DWfON0',
        'NYR' => 'https://www.youtube.com/watch?v=Zzfks2A2n38',
        'OTT' => 'https://www.youtube.com/watch?v=fHlWxPRNVBc',
        'PHI' => 'https://www.youtube.com/watch?v=0LsXpMiVD1E',
        'PIT' => 'https://www.youtube.com/watch?v=_asNhzXq72w',
        'SJS' => 'https://www.youtube.com/watch?v=NZqSBkmpbLw',
        'STL' => 'https://www.youtube.com/watch?v=Q23TDOJsY1s',
        'TBL' => 'https://www.youtube.com/watch?v=bdhDXxM20iM',
        'TOR' => 'https://www.youtube.com/watch?v=2cyekaemZgs',
        'VAN' => 'https://www.youtube.com/watch?v=CPozN-ZHpAo',
        'VGK' => 'https://www.youtube.com/watch?v=zheGI316WXg',
        'WPG' => 'https://www.youtube.com/watch?v=3gcahU_i9WE',
        'WSH' => 'https://www.youtube.com/watch?v=BH_CC1RxtfU',
    }
});

sub horn
{
    my ($self, $team) = @_;

    return undef unless defined $team;
    return undef unless length $team == 3;
    return undef unless $team =~ /^[A-Za-z]{3}$/;
    return $self->horns->{uc $team};
}

sub teams
{
    my ($self) = @_;

    return sort keys %{$self->horns};
}

1;
