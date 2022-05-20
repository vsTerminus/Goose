# To use: cpanm --installdeps .
requires 'Moo';                         # OO Framework
requires 'strictures' => '2';           # Enables strict and warnings with specific settings
requires 'namespace::clean';            # Removes declared and imported symbols from your compiled package
#requires 'Mojo::Discord';               # Discord Library
requires 'Mojo::WebService::LastFM';    # Last.FM Library
requires 'Mojo::IOLoop';                # Required for persistent websocket connection (Discord)
requires 'Mojo::JSON';                  # Used to translate to and from JSON for talking to APIs
requires 'Mojo::UserAgent';             # Used for HTTP(S) calls to APIs so we can customize our UA and options
requires 'Mojo::UserAgent::Role::Queued'; # Used for simultaneous connection limiting
requires 'Mojo::AsyncAwait';            # Brings async operations up a level compared to Mojo::Promise. Really nice syntax.
requires 'Mojo::DOM';                   # Used for iterating through XML instead of using regex
requires 'Mojo::Log';                   # Proper logging functionality
requires 'Math::Random::Secure';        # Used to generate true random values instead of relying on pseudo-random.
requires 'Math::Expression';            # Parsing math expression strings
requires 'Config::Tiny';                # .ini config file support
requires 'URI::Escape';                 # Escape URLs for use with APIs
requires 'URI::Encode';                 # Used to encode any text to be URL safe
requires 'Text::ASCIITable';            # Generate an ASCII table using data from perl structures
requires 'Time::Duration';              # Used for uptime calculation currently
requires 'DBI';                         # Database connection
requires 'FindBin' => '1.51';           # For including libs in the project directory
requires 'DateTime';                    # Used to get specifc-format unix epoch timestamps
requires 'Data::Dumper';                # Used for debugging
requires 'Geo::Distance';               # Calculate the distance pilots are from airfields in Hoggit.pm
requires 'Geo::ICAO';                   # Used for decoding the ICAO code in METARs
requires 'Games::Cards';                # For picking random playing cards
requires 'Unicode::UTF8';


# Testing
on 'test' => sub {
    requires 'Mojo::UserAgent::CookieJar::Role::Persistent'; # Used to save and load cookies between sessions
    requires 'Mojo::Base';
    requires 'File::Remove'; # Clean up test case artifacts
    requires 'Mojo::URL';
    requires 'Test::Fatal';
    requires 'Test::Memory::Cycle';
    requires 'Test::More';
};
