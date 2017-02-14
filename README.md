# About The Bot

This is a Discord bot built on the [Mojo::Discord](https://github.com/vsTerminus/Net-Discord) framework. It can do some potentially useful things on your server, mostly involving displaying information from other websites (eg YouTube and Last.FM).

If you aren't planning to host your own bot you can [invite my bot to your server](https://discordapp.com/oauth2/authorize?client_id=231059560977137664&scope=bot&permissions=536890368) instead. Just select the server you want to add it to and click the 'Authorize' button. If you don't have Manage Server permissions you can share this link with your Server Admin instead and ask them to do it: 

- https://discordapp.com/oauth2/authorize?client_id=231059560977137664&scope=bot&permissions=536890368

I have also created a [public discord server](https://discord.gg/FuKTcHF) you can use to monitor development progress, ask questions, request features, and so on. Feel free to join and share this invite link wherever you like.

- https://discord.gg/FuKTcHF

# Commands

So far the bot can do:

- **Avatar Lookups** | Fetch and display a slightly higher resolution version of someone's avatar

![Avatar Command Example](https://i.imgur.com/GCvgK0s.png)

- **Randomly Generated Comics** | Use the Cyanid & Happiness Random Comic Generator and save your favorites for later

![Comic Command Example](https://i.imgur.com/ISBg66k.png)

- **Last.FM Now Playing Info** | Fetch Last.FM information for yourself or anyone else who scrobbles their music

![Weather Command  Example](https://i.imgur.com/cneQT46.png)

- **Pick** | Give the bot a list of things to pick from and have it decide your fate

![Pick Command Example](https://i.imgur.com/nLo89qm.png)

- **Current Weather Conditions** | Look up the weather for just about anywhere in the world

![Weather Command Example](https://i.imgur.com/625CU8J.png)

- **YouTube Videos** | Search for videos on YouTube

![YouTube Command Example](https://i.imgur.com/g1Unk8Z.png)

- **Pretend You're Xyzzy** | Play individual, customized hands of (A Cards Against Humanity clone)

![Pretend You're Xyzzy Example](https://i.imgur.com/nQeHlZF.png)

There are also some commands which are restricted to the bot owner.
These are useful more for utility type commands which help the bot function.

- **Hook** | Manage webhooks that the bot can leverage for advanced formatting
- **Say** | Give the bot raw JSON strings to send - used to experiment with embeds and things mostly.
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

While you won't need an API Key for the Pretend You're Xyzzy functionality, you will need to set up [cah-cards](https://github.com/Grinnz/cah-cards) by [Grinnz](https://github.com/Grinnz) and put your web service URL in this bot's config file.

In addition, you'll need a database set up for some of the functions (Weather, comic, and nowplaying). 
I use MySQL and have not tested it with anything else, although in theory it should work with anything supported by Perl DBI.
Also, I have not included any sort of DB table schemas for this. If you are actually going to try to set this up, maybe open an issue or something and request the table layouts, otherwise you'll have to go through the code and figure out what you need to build.

# Layout

- **goose.pl**
    - This is the main script that you run to start the bot.
    - Any commands the bot needs should be initialized here, as well as the Bot object itself.
    - All this file does is initialize commands and then start the bot.
- **Bot/Goose.pm**
    - This is the main bot object.
    - All of the discord events are handled here.
    - All of the commands register themselves with this object, and it handles passing arguments to the various Command modules.
    - On its own, this module does very little. It mostly just waits for things to happen and then delegates work out to the Commands.
- **Command/\*.pm**
    - Each module here defines a single command usable in Discord.
    - The commands have direct access to things like the Discord connection object so they can send messages directly.
    - Basically, once the Bot module hands something off to a Command module, it forgets all about it and goes on with life. It's up to the Command module to send a response back to the user.
- **Component/\*.pm**
    - These are API wrapper modules for the Commands to use.
    - I could turn these into separate projects on their own like I did for Mojo::WebService::LastFM, but I won't do that unless I have some other project that wants to use them. 
    - Basically, if you want to connect to a new API you'd create a new Component module that handles the API calls, and then write a Command that uses the Component module to get what it needs.

That's about it. Maybe not the best, but it works.

# Troubleshooting

While you'll see in most of the sections that various components are optional, I have not done much testing with anything disabled and there is very little error handling (as this is a side project in my very limited free time), so if you decide you don't want to use certain commands/modules, be prepared for things to probably not totally work.

If it is not launching there are two very common scenarios to check first:

1. Is the config filled out properly and completely? API keys and user tokens should *not* have quotations around them.
2. Do you have all of the required modules? The simplest way to make sure you do is to install cpanminus and run it against the *cpanfile* included in this project.
    a. Don't forget that Mojo::Discord and Mojo::WebService::LastFM are not CPAN modules and have to be installed manually from my github page.

If you are running this on Windows, I highly recommend Strawberry Perl. It comes with cpanminus, and seems to be the best option. Beyond that, it should work as long as you have the config filled out and have all the required modules installed.

If you open an Issue I will do my best to respond quickly and hopefully with the info you need. It helps me if you include screenshots and/or copy/pasthe errors you're receiving. The more info you can give me, the less time of yours I have to waste asking for more info.

Beyond that... Good luck?

This is *not* a "just install and run it" type application. The code is mostly up on github now in case someone finds it useful or interesting, and so I can share what I'm doing with people. I hope to eventually have it be more user-friendly, but that day is not today.
