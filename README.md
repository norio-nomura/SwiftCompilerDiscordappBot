# Swift Compiler Discordapp Bot

Written in Swift.  
Inspired by [swift-compiler-discord-bot](https://github.com/kishikawakatsumi/swift-compiler-discord-bot).

## How to use

### Set Up Bot Account

[Creating a discord bot & getting a token](https://github.com/reactiflux/discord-irc/wiki/Creating-a-discord-bot-&-getting-a-token)

#### Required Permissions
- `CHANGE_NICKNAME` for update nickname
- `READ_MESSAGE_HISTORY` and `VIEW_CHANNEL` for update replies on updating request from user

### Test on local host

```terminal.sh-session
export DISCORD_TOKEN="<discord token here>" # set discord token
export DOCKER_IMAGE=norionomura/swift:41 # select docker image
docker-compose up
```

### Deploy to Heroku

```terminal.sh-session
git clone https://github.com/norio-nomura/SwiftCompilerDiscordappBot.git
cd SwiftCompilerDiscordappBot
heroku container:login
heroku create
heroku config:set DISCORD_TOKEN="<discord token here>"
heroku container:push worker --arg DOCKER_IMAGE=norionomura/swift:41
```
Configure Dyno on your [Heroku Dashboard](https://dashboard.heroku.com/apps)

## Author

Norio Nomura

## License

Swift Compiler Discordapp Bot is available under the MIT license. See the LICENSE file for more info.
