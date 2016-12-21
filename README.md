# Goose Bot

This is another Discord Bot build on my [Net::Discord](https://github.com/vsTerminus/Net-Discord) module, except this one is semi-useful.
This bot can take commands and potentially do things that people will enjoy.

I've built a number of commands so far, and the list is always growing (slowly).

# Commands

So far the bot can do:

- **Avatar** | Fetch and display a slightly higher resolution version of someone's avatar
- **Comic** | Generate a random Cyanid & Happiness comic, and save your favorites for later
- **NowPlaying** | Fetch Last.FM information for yourself or anyone else who scrobbles their music
- **Pick** | Give the bot a list of things to pick from and have it decide your fate
- **Weather** | Look up the weather for just about anywhere in the world

There are also some commands which are restricted to the bot owner.
These are useful more for utility type commands which help the bot function.

- **Leave** | Leave a guild (Server) that you no longer want the bot to be a member of
- **Play** | Change the bot's "Playing" status

# Configuration

As with some of my other projects here, there is a **config.ini.example** file included here which you can copy or rename to **config.ini** and then fill out. The file does an OK job of explaining what you need, but here is a brief rundown.

In short, you will need to sign up for a number of developer API keys from various websites to make the bot capable of interacting with those services.

- Discord (Create a Bot User and get its Token)
- Last.FM (API Key)
- Google Maps (API Key)
- YouTube (API Key)
- DarkSky.net (API Key)

In addition, you'll need a database set up for some of the functions (Weather, comic, and nowplaying). 
I use MySQL and have not tested it with anything else, although in theory it should work with anything supported by Perl DBI.
Also, I have not included any sort of DB table schemas for this. If you are actually going to try to set this up, maybe open an issue or something and request the table layouts, otherwise you'll have to go through the code and figure out what you need to build.

# Troubleshooting

While you'll see in most of the sections that various components are optional, I have not done much testing with anything disabled and there is very little error handling (as this is a side project in my very limited free time), so if you decide you don't want to use certain commands/modules, be prepared for things to probably not totally work.

If it is not launching there are two very common scenarios to check first:

1. Is the config filled out properly and completely? API keys and user tokens should *not* have quotations around them.
2. Do you have all of the required modules? The simplest way to make sure you do is to install cpanminus and run it against the *cpanfile* included in this project.
    a. Don't forget that Net::Discord and Net::Async::LastFM are not CPAN modules and have to be installed manually from my github page.

If you are running this on Windows, I highly recommend Strawberry Perl. It comes with cpanminus, and seems to be the best option. Beyond that, it should work as long as you have the config filled out and have all the required modules installed.

If you open an Issue I will do my best to respond quickly and hopefully with the info you need. It helps me if you include screenshots and/or copy/pasthe errors you're receiving. The more info you can give me, the less time of yours I have to waste asking for more info.

Beyond that... Good luck?

This is *not* a "just install and run it" type application. The code is mostly up on github now in case someone finds it useful or interesting, and so I can share what I'm doing with people. I hope to eventually have it be more user-friendly, but that day is not today.
