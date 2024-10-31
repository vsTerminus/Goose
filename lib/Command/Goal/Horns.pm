package Command::Goal::Horns;

use Moo;
use strictures 2;

use namespace::clean;

# Teams and links provided by NYVideoGameFreak. Thanks John!
has horns   => ( is => 'ro', default => sub {
    {
        'ANA' => 'https://www.youtube.com/watch?v=ROYnAU_0AWc',
        'UTA' => 'https://www.youtube.com/watch?v=l7YXIvXJzu8',
        'BOS' => 'https://www.youtube.com/watch?v=kHE2JoekSNk',
        'BUF' => 'https://www.youtube.com/watch?v=GRsptYdx0gA',
        'CAR' => 'https://www.youtube.com/watch?v=F40DKRJHbvA',
        'CGY' => 'https://www.youtube.com/watch?v=tC4pSEGZ4Nk',
        'CHI' => 'https://www.youtube.com/watch?v=x_JCSKe3C0Q',
        'CBJ' => 'https://www.youtube.com/watch?v=dyewPKAwBE8',
        'COL' => 'https://www.youtube.com/watch?v=VZH4S-6ww9M',
        'DAL' => 'https://www.youtube.com/watch?v=8QA1hIZQ5HA',
        'DET' => 'https://www.youtube.com/watch?v=sFAwUGj23Wg',
        'EDM' => 'https://www.youtube.com/watch?v=03cpCjcYhlM',
        'FLA' => 'https://www.youtube.com/watch?v=TJdRkgSQp3A',
        'LAK' => 'https://www.youtube.com/watch?v=5nTaXdJmRYg',
        'MIN' => 'https://www.youtube.com/watch?v=7bw7laBYa4M',
        'MTL' => 'https://www.youtube.com/watch?v=qgIOXoHwOeM',
        'NSH' => 'https://www.youtube.com/watch?v=k-tC82siSso',
        'NJD' => 'https://www.youtube.com/watch?v=p9x0Kek9B78',
        'NYI' => 'https://www.youtube.com/watch?v=PGIhQCooVno',
        'NYR' => 'https://www.youtube.com/watch?v=6elwxTD4YGg',
        'OTT' => 'https://www.youtube.com/watch?v=aJq5cHxLo8Q',
        'PHI' => 'https://www.youtube.com/watch?v=UpMiLuKEpNM',
        'PIT' => 'https://www.youtube.com/watch?v=WmyaMOrKbCw',
        'SJS' => 'https://www.youtube.com/watch?v=zvKywmf0IKw',
        'STL' => 'https://www.youtube.com/watch?v=rDYHPJElOo8',
        'TBL' => 'https://www.youtube.com/watch?v=KD7jokQ3vbY',
        'TOR' => 'https://www.youtube.com/watch?v=_-kYVCSbze4',
        'VAN' => 'https://www.youtube.com/watch?v=yJkijlLvMLs',
        'VGK' => 'https://www.youtube.com/watch?v=om53osHrUiA',
        'WPG' => 'https://www.youtube.com/watch?v=Hdbb3_ScMOM',
        'WSH' => 'https://www.youtube.com/watch?v=IvTDItkN1aA',
        'SEA' => 'https://www.youtube.com/watch?v=SosdN8ngdIA',
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
