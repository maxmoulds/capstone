#!/usr/bin/env bash
ORGANIZATION=openstax
curl -s https://api.github.com/orgs/openstax/repos | ruby -rubygems -e 'require "json"; JSON.load(STDIN.read).each {|repo| %x[git clone #{repo["clone_url"]} ]}'
