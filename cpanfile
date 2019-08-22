# To use: cpanm --installdeps .
requires 'Moo';                         # OO Framework
requires 'Mojo::Discord';               # Discord Library
requires 'Mojo::WebService::LastFM';    # Last.FM Library
requires 'Mojo::IOLoop';                # Required for persistent websocket connection (Discord)
requires 'Mojo::JSON';                  # Used to translate to and from JSON for talking to APIs
requires 'Mojo::UserAgent';             # Used for HTTP(S) calls to APIs so we can customize our UA and options
requires 'Mojo::AsyncAwait';            # Brings async operations up a level compared to Mojo::Promise. Really nice syntax.
requires 'Math::Random::Secure';        # Used to generate true random values instead of relying on pseudo-random.
requires 'Math::Expression';            # Parsing math expression strings
requires 'Config::Tiny';                # .ini config file support
requires 'URI::Escape';                 # Escape URLs for use with APIs
requires 'Text::ASCIITable'             # Generate an ASCII table using data from perl structures
