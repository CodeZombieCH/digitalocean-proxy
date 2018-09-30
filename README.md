# DigitalOcean proxy

A shell script to run a disposable proxy on a DigitalOcean droplet


## Features

- Allows starting and stopping a disposable proxy on a DigitalOcean droplet
- Access to proxy is whitelisted by the public IP of the system starting the proxy
- Based on squid proxy


## Requirements

- DigitalOcean account and API token
- curl
- jq v1.3+

Tested on Ubuntu 14.04.5 LTS with
- curl v7.35.0
- jq v1.3


## Installation

1. Clone the repository
2. Make script file executable

        chmod +x ./proxy-droplet.sh


## Configuration

Set the follwing environment variables used by the script

    # Set DigitalOcean API token
    export DIGITALOCEAN_TOKEN='<your-token>'
    # Set SSH key to use
    export SSH_KEY=<path-to-key>


## Usage

### Synopsis

    ./proxy-droplet.sh <command>

where `<command>` can be one of the following commands

- `start`:

    Start the proxy droplet (creates a new droplet)

- `stop`:

    Stop the proxy droplet (deletes the droplet)

- `status`:

    Check status


## Ideas

- Verbose mode
- Write bootstrap.sh script that pulls `droplet-blueprint.json` and `droplet-init.sh` from GitHub
- Self destruction
- Command to update IP whitelist
- Attach iftop
- Attach access log
- Support different hosting providers (e.g. Linode)
- Support different proxy software (e.g. Tinyproxy)
- Consider porting to Python 3 to for easier distribution through PIP


## Changelog

See CHANGELOG.md


## License

See LICENSE file


## Credits

This script was improved by some ideas and snippets from the [gist by Henrik Feldt](https://gist.github.com/haf/7d80fc4527d4733aef0c)
that showed me how to write a more proper shell script. Thank you Henrik.
